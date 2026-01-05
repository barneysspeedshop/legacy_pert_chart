import 'dart:ui';
import 'dart:math';
import 'models/pert_task.dart';

/// A layout engine for positioning PERT tasks (nodes) automatically.
///
/// The engine calculates a "Rank" (X-axis) and "Lane" (Y-axis) for each task based on its
/// dependencies. It ensures that:
/// 1. Successors always appear to the right of their predecessors (Topological Sort).
/// 2. Tasks are distributed vertically to minimize crossings (basic heuristic).
///
/// The layout result is a map of `(id -> Offset)` that can be used by the [PertPainter]
/// and [LegacyPertChartWidget] to render the diagram.
class PertLayout {
  /// The fixed width of a node in the diagram.
  static const double nodeWidth = 120.0;

  /// The fixed height of a node in the diagram.
  static const double nodeHeight = 60.0;

  /// The horizontal spacing between ranks (columns).
  static const double rankSpacing = 200.0;

  /// The vertical spacing between nodes within the same rank.
  static const double nodeSpacing = 100.0;

  /// Calculates the positions for a list of [tasks].
  ///
  /// Returns a record containing:
  /// * `positions`: A map of Task ID to the center [Offset] of the node.
  /// * `size`: The total [Size] of the diagram based on the computed bounding box.
  ({Map<String, Offset> positions, Size size}) calculateLayout(
      List<LegacyPertTask> tasks) {
    if (tasks.isEmpty) {
      return (positions: {}, size: Size.zero);
    }

    final taskMap = {for (var t in tasks) t.id: t};
    final ranks = _calculateRanks(tasks, taskMap);

    // Group tasks by rank
    final tasksByRank = <int, List<String>>{};
    int maxRank = 0;
    for (var entry in ranks.entries) {
      tasksByRank.putIfAbsent(entry.value, () => []).add(entry.key);
      maxRank = max(maxRank, entry.value);
    }

    // 2. Identify Lanes and Group Tasks
    final lanes = tasks.map((t) => t.laneId).toSet().toList();
    lanes.sort((a, b) => (a ?? '').compareTo(b ?? ''));

    // Calculate Row assignments for local vertical layout
    // Map<String, int> taskRowAssignments
    final taskRowAssignments = <String, int>{};
    final laneRowExtents = <String?, ({int minRow, int maxRow})>{};

    for (var rank = 0; rank <= maxRank; rank++) {
      final rankTasks = tasksByRank[rank] ?? [];

      // Group by Lane
      final rankTasksByLane = <String?, List<String>>{};
      for (var tId in rankTasks) {
        final t = taskMap[tId];
        if (t == null) {
          continue; // Skip ghost tasks (referenced in deps but not in list)
        }
        rankTasksByLane.putIfAbsent(t.laneId, () => []).add(tId);
      }

      for (var lane in lanes) {
        final laneTasks = rankTasksByLane[lane] ?? [];
        if (laneTasks.isEmpty) continue;

        // Sort: Critical task first (to grab Row 0), then by ID
        laneTasks.sort((a, b) {
          final tA = taskMap[a]!;
          final tB = taskMap[b]!;
          if (tA.isCritical && !tB.isCritical) return -1;
          if (!tA.isCritical && tB.isCritical) return 1;
          return a.compareTo(b);
        });

        // Spiral assignment: 0, 1, -1, 2, -2
        // If first is critical, it gets 0.
        for (var i = 0; i < laneTasks.length; i++) {
          final taskId = laneTasks[i];
          // 0, 1, -1, 2, -2 ...
          // i=0 -> 0
          // i=1 -> 1
          // i=2 -> -1
          // i=3 -> 2
          // i=4 -> -2
          int row = 0;
          if (i > 0) {
            int magnitude = (i + 1) ~/ 2;
            row = (i % 2 == 1) ? magnitude : -magnitude;
          }

          taskRowAssignments[taskId] = row;

          // Track extents for Lane Height
          var extents = laneRowExtents[lane] ?? (minRow: 0, maxRow: 0);
          laneRowExtents[lane] = (
            minRow: min(extents.minRow, row),
            maxRow: max(extents.maxRow, row)
          );
        }
      }
    }

    // Calculate Lane Heights and Y Offsets
    final laneHeights = <String?, double>{};
    final laneCenterY = <String?, double>{};
    double currentY = 50.0; // Top padding

    for (var lane in lanes) {
      final extents = laneRowExtents[lane] ?? (minRow: 0, maxRow: 0);
      final rowsAbove = -extents.minRow; // e.g. min -2 => 2 rows above center
      final rowsBelow = extents.maxRow; // e.g. max 2 => 2 rows below center
      final totalRows = rowsAbove + 1 + rowsBelow;

      final height =
          totalRows * (nodeHeight + nodeSpacing) - nodeSpacing; // Visual height

      // We want the 'Center' row (Row 0) to be at currentY + rowsAbove * spacing + item/2?
      // Better:
      // Lane starts at currentY.
      // Row 0 is at offset: rowsAbove * (H+S).

      final row0Offset = rowsAbove * (nodeHeight + nodeSpacing);
      final center =
          currentY + 50.0 + row0Offset + nodeHeight / 2; // +50 padding

      laneCenterY[lane] = center;
      laneHeights[lane] =
          max(height + 100.0, nodeHeight + 100.0); // Ensure min height

      currentY += laneHeights[lane]!;
    }

    // X Coordinates (Rank based)
    final rankX = <int, double>{};
    double currentX = 50.0;
    for (var r = 0; r <= maxRank; r++) {
      rankX[r] = currentX + nodeWidth / 2;
      currentX += nodeWidth + rankSpacing;
    }

    // Assign Positions
    final positions = <String, Offset>{};
    for (var task in tasks) {
      final x = rankX[ranks[task.id]!]!;
      final lane = task.laneId;
      final centerY = laneCenterY[lane]!;
      final row = taskRowAssignments[task.id]!;

      // Y = Center + Row * (H + S)
      final y = centerY + row * (nodeHeight + nodeSpacing);

      positions[task.id] = Offset(x, y);
    }

    return (positions: positions, size: Size(currentX, currentY));
  }

  Map<String, int> _calculateRanks(
      List<LegacyPertTask> tasks, Map<String, LegacyPertTask> taskMap) {
    final ranks = <String, int>{};
    final visited = <String>{};
    final visiting = <String>{};

    int getRank(String taskId) {
      if (ranks.containsKey(taskId)) return ranks[taskId]!;
      if (visiting.contains(taskId)) return 0; // Cycle detected, fallback

      visiting.add(taskId);

      final task = taskMap[taskId];
      if (task == null) {
        visiting.remove(taskId);
        visited.add(taskId);
        return ranks[taskId] = 0;
      }

      int maxDependencyRank = -1;
      for (var depId in task.dependencyIds) {
        final depRank = getRank(depId);
        if (depRank > maxDependencyRank) {
          maxDependencyRank = depRank;
        }
      }

      // Implicit Rule: Child must be to the right of Parent (Lane Header)
      if (task.laneId != null && task.laneId != taskId) {
        final parentId = task.laneId!;
        // Ensure parent actually exists in the map to avoid infinite fallback or crash
        if (taskMap.containsKey(parentId)) {
          final parentRank = getRank(parentId);
          if (parentRank > maxDependencyRank) {
            maxDependencyRank = parentRank;
          }
        }
      }

      visiting.remove(taskId);
      visited.add(taskId);
      return ranks[taskId] = maxDependencyRank + 1;
    }

    for (var task in tasks) {
      if (!visited.contains(task.id)) {
        getRank(task.id);
      }
    }

    return ranks;
  }
}
