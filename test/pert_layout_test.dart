import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_pert_chart/src/models/pert_task.dart';
import 'package:legacy_pert_chart/src/pert_layout.dart';

void main() {
  test('PertLayout calculates positions correctly for simple graph', () {
    final layout = PertLayout();
    final tasks = [
      const LegacyPertTask(id: '1', name: 'Start'),
      const LegacyPertTask(id: '2', name: 'Middle', dependencyIds: ['1']),
      const LegacyPertTask(id: '3', name: 'End', dependencyIds: ['2']),
    ];

    final result = layout.calculateLayout(tasks);

    expect(result.positions.length, 3);

    // Check ranks indirectly via X coordinates
    // Rank 0 (Start) < Rank 1 (Middle) < Rank 2 (End)
    expect(result.positions['1']!.dx, lessThan(result.positions['2']!.dx));
    expect(result.positions['2']!.dx, lessThan(result.positions['3']!.dx));
  });

  test('PertLayout handles disjoint graphs', () {
    final layout = PertLayout();
    final tasks = [
      const LegacyPertTask(id: '1', name: 'A'),
      const LegacyPertTask(id: '2', name: 'B'), // No dependency
    ];

    final result = layout.calculateLayout(tasks);

    // Both should be rank 0, so same X
    expect(result.positions['1']!.dx, equals(result.positions['2']!.dx));
    // Different Y
    expect(result.positions['1']!.dy, isNot(equals(result.positions['2']!.dy)));
  });
}
