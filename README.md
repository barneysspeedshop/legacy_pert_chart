# legacy_pert_chart

### Sovereign Logic. Native Performance.

A high-performance PERT (Program Evaluation and Review Technique) and Network Diagram widget for Flutter. Unlike competitors that require "Server Modules" or Node.js middleware to handle layout logic, `legacy_pert_chart` runs its advanced `PertLayout` engine 100% on-device.

## Features

*   **No Server Sidecars**: The layout logic is compiled native Dart. It does not require a backend service to calculate ranks or lanes.
*   **Automated Ranking Algorithm**: The `PertLayout` engine automatically organizes thousands of non-linear dependencies into logical flow-states, revealing structure in chaotic data.
*   **Seamless Integration**: Built on the same `LegacyGanttTask` models as `legacy_gantt_chart`, allowing you to switch between Gantt and PERT views instantly.
*   **Full Customization**: Supports custom `nodeBuilder` functions, giving you complete control over the look and feel of every node.
*   **Interactive**: Native Flutter performance with smooth zooming, panning, and hit-testing (120 FPS).

## Getting Started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  legacy_pert_chart: ^0.0.1
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:legacy_pert_chart/legacy_pert_chart.dart';
import 'package:legacy_gantt_chart/legacy_gantt_chart.dart';

class MyPertChart extends StatelessWidget {
  final List<LegacyGanttTask> tasks;

  const MyPertChart({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    return LegacyPertChartWidget(
      tasks: tasks,
      nodeBuilder: (context, task, layout) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Text(task.name)),
        );
      },
    );
  }
}
```

## Enterprise Integration

This package is part of the **GanttSync Ecosystem**.

*   **FOSS Core**: The UI and layout logic are 100% free and open source (MIT). **We Don't Gate Pixels.**
*   **Real-Time Sync**: Connect this chart to **GanttSync** for offline-first, real-time collaboration. The Enterprise edition provides "Sync-Aware Controllers" that handle live updates, multi-user cursors, and instant critical path recalculation across the network.

[Learn more about GanttSync](https://gantt-sync.com)
