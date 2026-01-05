import 'dart:async';
import 'package:flutter/material.dart';
import 'package:legacy_gantt_chart/legacy_gantt_chart.dart';
import 'package:legacy_pert_chart/legacy_pert_chart.dart';

class PertViewModel extends ChangeNotifier {
  WebSocketGanttSyncClient? _client;

  List<LegacyPertTask> _tasks = [];
  List<LegacyPertTask> get tasks => _tasks;

  // Store raw Gantt tasks and dependencies to rebuild PERT tasks
  final Map<String, LegacyGanttTask> _ganttTasks = {};
  final List<LegacyGanttTaskDependency> _dependencies = [];

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _error;
  String? get error => _error;

  Stream<int> get outboundPendingCount =>
      _client?.outboundPendingCount ?? Stream.value(0);
  Stream<SyncProgress> get inboundProgress =>
      _client?.inboundProgress ??
      Stream.value(SyncProgress(processed: 0, total: 0));

  Future<void> connect({
    required String uri,
    required String tenantId,
    required String username,
    required String password,
  }) async {
    _error = null;
    notifyListeners();

    try {
      final parsedUri = Uri.parse(uri);

      // 1. Login to get token
      final token = await WebSocketGanttSyncClient.login(
        uri: parsedUri,
        username: username,
        password: password,
      );

      // 2. Initialize client with token (convert http/s to ws/s)
      final wsScheme = parsedUri.scheme == 'https' ? 'wss' : 'ws';
      final wsUri = parsedUri.replace(scheme: wsScheme, path: '/ws');

      _client = WebSocketGanttSyncClient(uri: wsUri, authToken: token);

      // 3. Connect to the channel
      _client!.connect(tenantId);

      _isConnected = true;
      notifyListeners();

      // 4. Listen for operations
      _client!.operationStream.listen(
        _handleOperation,
        onError: (e) {
          _error = e.toString();
          _isConnected = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _error = e.toString();
      _isConnected = false;
      notifyListeners();
    }
  }

  void disconnect() {
    _client?.dispose(); // Changed from disconnect() to dispose()
    _client = null;
    _isConnected = false;
    _ganttTasks.clear();
    _dependencies.clear();
    _rebuildPertTasks();
    notifyListeners();
  }

  void _handleOperation(Operation op) {
    bool changed = _processOperation(op);

    if (changed) {
      _rebuildPertTasks();
      notifyListeners();
    }
  }

  bool _processOperation(Operation op) {
    bool changed = false;
    switch (op.type) {
      case 'BATCH_UPDATE':
        final operations = op.data['operations'] as List;
        for (final rawOp in operations) {
          final innerOp = Operation(
            type: rawOp['type'],
            data: rawOp['data'],
            timestamp: op.timestamp, // Use batch timestamp
            actorId: op.actorId,
          );
          if (_processOperation(innerOp)) {
            changed = true;
          }
        }
        break;

      case 'INSERT_TASK':
      case 'UPDATE_TASK':
        final data = op.data;
        // Handle nested 'data' if present (protocol variation)
        final taskData = data.containsKey('data')
            ? data['data'] as Map<String, dynamic>
            : data;

        final task = LegacyGanttTask(
          id: taskData['id'],
          rowId:
              taskData['rowId'] ??
              taskData['resourceId'] ??
              'default_row', // Added required rowId
          name: taskData['name'] ?? 'Unnamed',
          start: _parseDate(taskData['start'] ?? taskData['start_date']),
          end: _parseDate(taskData['end'] ?? taskData['end_date']),
          parentId:
              taskData['parentId'], // Map parentId specifically for hierarchy
        );
        _ganttTasks[task.id] = task;
        changed = true;
        break;

      case 'DELETE_TASK':
        final id = op.data['id'];
        _ganttTasks.remove(id);
        // Also remove related dependencies
        _dependencies.removeWhere(
          (d) => d.predecessorTaskId == id || d.successorTaskId == id,
        );
        changed = true;
        break;

      case 'INSERT_DEPENDENCY':
        final data = op.data.containsKey('data')
            ? op.data['data'] as Map<String, dynamic>
            : op.data;
        final predId = data['predecessorTaskId'] ?? data['predecessor_task_id'];
        final succId = data['successorTaskId'] ?? data['successor_task_id'];

        if (predId != null && succId != null) {
          final dep = LegacyGanttTaskDependency(
            predecessorTaskId: predId,
            successorTaskId: succId,
            type: DependencyType.values.firstWhere(
              (e) =>
                  e.name.toLowerCase() ==
                  data['dependency_type'].toString().toLowerCase(),
              orElse: () => DependencyType.finishToStart,
            ),
          );
          _dependencies.add(dep);
          changed = true;
        } else {
          // Skipped dependency due to null IDs
        }
        break;

      case 'DELETE_DEPENDENCY':
        final data = op.data.containsKey('data')
            ? op.data['data'] as Map<String, dynamic>
            : op.data;
        _dependencies.removeWhere(
          (d) =>
              d.predecessorTaskId ==
                  (data['predecessorTaskId'] ?? data['predecessor_task_id']) &&
              d.successorTaskId ==
                  (data['successorTaskId'] ?? data['successor_task_id']),
        );
        changed = true;
        break;

      case 'RESET_DATA':
        _ganttTasks.clear();
        _dependencies.clear();
        changed = true;
        break;
    }
    return changed;
  }

  void _rebuildPertTasks() {
    // 1. Identify hierarchy (Swimlanes)
    final childToParent = <String, String>{};
    final parents = <String>{};

    for (final dep in _dependencies) {
      if (dep.type == DependencyType.contained) {
        childToParent[dep.successorTaskId] = dep.predecessorTaskId;
        parents.add(dep.predecessorTaskId);
      }
    }

    // 2. Synthesize Dependencies if missing (Fix for "Shotgun" / "Zig-Zag")
    var effectiveDependencies = <LegacyGanttTaskDependency>[..._dependencies];

    if (effectiveDependencies.isEmpty) {
      effectiveDependencies.addAll(_synthesizeDependencies());
    }

    // 3. Filter Transitive Redundancies (A->B, B->C, A->C => Remove A->C)
    // Only consider paths valid if they pass through EXISTING tasks.
    // This prevents "Ghost Paths" (via missing tasks) from hiding visible links.
    final validTaskIds = _ganttTasks.keys.toSet();
    effectiveDependencies = _removeTransitiveRedundancies(
      effectiveDependencies,
      validTaskIds,
    );

    // 3. Calculate Critical Path
    final calculator = CriticalPathCalculator();
    final cpmResult = calculator.calculate(
      tasks: _ganttTasks.values.toList(),
      dependencies: effectiveDependencies,
    );

    // 3. Build Pert Tasks (Keep Summary Tasks now)
    _tasks = _ganttTasks.values.map((ganttTask) {
      // Filter out 'contained' dependencies as PERT charts show sequence.
      // We will handle hierarchy via layout ranks, not visible arrows.
      final deps = effectiveDependencies
          .where(
            (d) =>
                d.successorTaskId == ganttTask.id &&
                d.type != DependencyType.contained,
          )
          .map((d) => d.predecessorTaskId)
          .toList();

      // Determine Lane ID
      // 1. Try parentId (Hierarchy)
      // 2. Try resourceId (Assignment/Grouping)
      String? laneId = ganttTask.parentId ?? ganttTask.resourceId;

      // 3. Fallback: If no parent, but it IS a parent (referenced by others), it's a lane header
      // This MUST check first, otherwise Regex will split the Summary Task (Regex ID) from its children (Parent ID)
      if (laneId == null) {
        final isParent = _ganttTasks.values.any(
          (t) => t.parentId == ganttTask.id || t.resourceId == ganttTask.id,
        );
        if (isParent) {
          laneId = ganttTask.id;
        }
      }

      // 4. Fallback: Parse Name (for Server Data compatibility)
      // Extract '0' from 'Task 0-1' or 'Person 0'
      if (laneId == null && ganttTask.name != null) {
        final name = ganttTask.name!;
        final taskMatch = RegExp(r'^Task (\d+)-').firstMatch(name);
        final personMatch = RegExp(r'Person (\d+)').firstMatch(name);

        if (taskMatch != null) {
          laneId = 'simulated-lane-${taskMatch.group(1)}';
        } else if (personMatch != null) {
          laneId = 'simulated-lane-${personMatch.group(1)}';
        }
      }

      return LegacyPertTask(
        id: ganttTask.id,
        name: ganttTask.name ?? 'Unnamed',
        dependencyIds: deps,
        laneId: laneId, // Null for tasks with no hierarchy info
        isCritical: cpmResult.criticalTaskIds.contains(ganttTask.id),
        duration: ganttTask.end.difference(ganttTask.start),
      );
    }).toList();
  }

  List<LegacyGanttTaskDependency> _synthesizeDependencies() {
    final syntheticDeps = <LegacyGanttTaskDependency>[];

    // Group by Parent ID to find siblings
    final siblingsMap = <String, List<LegacyGanttTask>>{};

    // Also track who IS a parent to exclude them from the chain (Summary Tasks shouldn't be IN the chain of children)
    final parentIds = _ganttTasks.values
        .map((t) => t.parentId)
        .whereType<String>()
        .toSet();

    for (var task in _ganttTasks.values) {
      // If this task is a Summary Task (it is a parent to others), skip chaining it?
      // Or maybe keep it standalone. For now, let's focus on leaf nodes.
      if (parentIds.contains(task.id)) continue;

      final key = task.parentId ?? task.resourceId ?? 'orphan';
      siblingsMap.putIfAbsent(key, () => []).add(task);
    }

    // Sort and Chain
    for (var siblings in siblingsMap.values) {
      siblings.sort((a, b) => a.start.compareTo(b.start));

      for (int i = 0; i < siblings.length - 1; i++) {
        final current = siblings[i];
        final next = siblings[i + 1];

        // Only link if there is a plausible time relation (Next starts at or after Current start)
        // Strictly, Waterfall means Next starts after Current Ends?
        // User says: "Task 0-1 cannot start until Task 0-0 finishes."
        // Our Mock data has exact overlap (End 0 == Start 1).
        // So we link i -> i+1.

        syntheticDeps.add(
          LegacyGanttTaskDependency(
            predecessorTaskId: current.id,
            successorTaskId: next.id,
            type: DependencyType.finishToStart,
          ),
        );
      }
    }
    return syntheticDeps;
  }

  List<LegacyGanttTaskDependency> _removeTransitiveRedundancies(
    List<LegacyGanttTaskDependency> sourceParams,
    Set<String> validTaskIds,
  ) {
    // 1. Convert to Adjacency List (Successors)
    final adj = <String, Set<String>>{};
    for (var dep in sourceParams) {
      if (dep.type != DependencyType.contained) {
        adj
            .putIfAbsent(dep.predecessorTaskId, () => {})
            .add(dep.successorTaskId);
      }
    }

    final toRemove = <LegacyGanttTaskDependency>{};

    // 2. Helper: Can we reach Target from Start using BFS?
    bool canReach(String start, String target, Map<String, Set<String>> graph) {
      final queue = <String>[start];
      final visited = <String>{start};

      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        if (current == target) return true;

        for (var neighbor in graph[current] ?? {}) {
          if (!visited.contains(neighbor)) {
            // CRITICAL FIX: Only traverse through VALID tasks.
            // If a path goes through a "missing" task, it's not a visible redundancy.
            if (neighbor != target && !validTaskIds.contains(neighbor)) {
              continue;
            }

            visited.add(neighbor);
            queue.add(neighbor);
          }
        }
      }
      return false;
    }

    // 3. Check each edge
    for (var dep in sourceParams) {
      if (dep.type == DependencyType.contained) continue;

      final u = dep.predecessorTaskId;
      final v = dep.successorTaskId;

      // Only check redundancies for visible nodes
      if (!validTaskIds.contains(u) || !validTaskIds.contains(v)) continue;

      // Temporarily remove direct edge u->v from graph view
      adj[u]?.remove(v);

      // Check if v is still reachable from u via other paths
      if (canReach(u, v, adj)) {
        // Redundant! u->v exists, but u->...->v also exists.
        toRemove.add(dep);
      }

      // Restore edge for future checks (Standard Transitive Reduction iterates all)
      // Actually, if we remove A->C, we shouldn't use it for A->D?
      // Standard algorithm typically iterates edges.
      // If we restore it, we are conservative.
      if (!toRemove.contains(dep)) {
        adj[u]?.add(v);
      }
    }

    // 4. Return filtered list
    return sourceParams.where((d) => !toRemove.contains(d)).toList();
  }

  DateTime _parseDate(dynamic input) {
    if (input == null) return DateTime.now();
    if (input is int) return DateTime.fromMillisecondsSinceEpoch(input);
    if (input is String) {
      final numeric = int.tryParse(input);
      if (numeric != null) {
        return DateTime.fromMillisecondsSinceEpoch(numeric);
      }
      return DateTime.parse(input);
    }
    return DateTime.now();
  }
}
