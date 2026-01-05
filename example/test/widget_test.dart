import 'package:flutter_test/flutter_test.dart';

import 'package:legacy_pert_chart/legacy_pert_chart.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('LegacyPertChartWidget smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the PERT chart widget is present.
    expect(find.byType(LegacyPertChartWidget), findsOneWidget);

    // Verify that sample tasks are displayed (since ViewModel starts with empty tasks but falls back to sample)
    // Note: The PertViewModel is mocked or real?
    // In the actual app, it starts empty and _getSampleTasks() is used if empty.
    // So 'Start' and 'Task A' should be visible.

    // However, the PertViewModel in main.dart might initialize empty.
    // Looking at main.dart:
    // viewModel.isConnected && tasks.isEmpty ? Waiting : LegacyPertChartWidget(tasks.isEmpty ? sample : tasks)
    // Initially isConnected is false. So it shows LegacyPertChartWidget with sample tasks.

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Task A'), findsOneWidget);
    expect(find.text('End'), findsOneWidget);
  });
}
