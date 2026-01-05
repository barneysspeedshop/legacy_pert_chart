import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_pert_chart/legacy_pert_chart.dart';

void main() {
  testWidgets('LegacyPertChartWidget builds correctly',
      (WidgetTester tester) async {
    const tasks = [
      LegacyPertTask(id: '1', name: 'Task 1'),
      LegacyPertTask(id: '2', name: 'Task 2', dependencyIds: ['1']),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: LegacyPertChartWidget(tasks: tasks),
      ),
    );

    expect(
        find.descendant(
            of: find.byType(LegacyPertChartWidget),
            matching: find.byType(CustomPaint)),
        findsOneWidget);
  });
}
