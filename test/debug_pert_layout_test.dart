import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_gantt_chart/legacy_gantt_chart.dart';

void main() {
  test('Transitive Reduction Logic', () {
    // 0 -> 1
    // 1 -> 2
    // 0 -> 2 (Redundant)
    final source = [
      LegacyGanttTaskDependency(
          predecessorTaskId: '0',
          successorTaskId: '1',
          type: DependencyType.finishToStart),
      LegacyGanttTaskDependency(
          predecessorTaskId: '1',
          successorTaskId: '2',
          type: DependencyType.finishToStart),
      LegacyGanttTaskDependency(
          predecessorTaskId: '0',
          successorTaskId: '2',
          type: DependencyType.finishToStart),
    ];

    // Local implementation of the logic found in PertViewModel for testing purposes
    List<LegacyGanttTaskDependency> removeTransitiveRedundancies(
        List<LegacyGanttTaskDependency> params) {
      final adj = <String, Set<String>>{};
      for (var dep in params) {
        if (dep.type != DependencyType.contained) {
          adj
              .putIfAbsent(dep.predecessorTaskId, () => {})
              .add(dep.successorTaskId);
        }
      }

      final toRemove = <LegacyGanttTaskDependency>{};

      bool canReach(
          String start, String target, Map<String, Set<String>> graph) {
        final queue = <String>[start];
        final visited = <String>{start};

        while (queue.isNotEmpty) {
          final current = queue.removeAt(0);
          if (current == target) return true;

          for (var neighbor in graph[current] ?? {}) {
            if (!visited.contains(neighbor)) {
              visited.add(neighbor);
              queue.add(neighbor);
            }
          }
        }
        return false;
      }

      for (var dep in params) {
        if (dep.type == DependencyType.contained) continue;
        final u = dep.predecessorTaskId;
        final v = dep.successorTaskId;

        adj[u]?.remove(v);

        if (canReach(u, v, adj)) {
          toRemove.add(dep);
        } else {
          if (!toRemove.contains(dep)) {
            adj[u]?.add(v);
          }
        }
      }
      return params.where((d) => !toRemove.contains(d)).toList();
    }

    final result = removeTransitiveRedundancies(source);

    expect(result.length, 2);
    expect(
        result
            .any((d) => d.predecessorTaskId == '0' && d.successorTaskId == '2'),
        isFalse);
    expect(
        result
            .any((d) => d.predecessorTaskId == '0' && d.successorTaskId == '1'),
        isTrue);
    expect(
        result
            .any((d) => d.predecessorTaskId == '1' && d.successorTaskId == '2'),
        isTrue);
  });
}
