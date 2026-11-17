## 0.2.0

* **BREAKING**: Align with legacy_gantt_chart ^9.0.0 and legacy_gantt_protocol ^3.0.0. Require Dart 3.10 and Flutter 3.38 or newer.
* PERT visualization remains client-side and does not depend on the experimental Rust scheduler.

## 0.1.0

* **FEATURE**: Added interactivity support! You can now drag between nodes to create dependencies (`onDependencyAdded`).
* **FEATURE**: Added `onNodeTap` callback to handle user interactions with tasks.
* **FEATURE**: Added `dragSource` and `dragTarget` to `PertPainter` for visualizing active drag operations.
* **BREAKING**: `LegacyPertChartWidget` now requires an `onDependencyAdded` callback if you want to support interactivity (optional, but worth noting).

## 0.0.2

* **FIX**: Fix URLs for the repository

## 0.0.1

* Initial Open Source release.
* Features:
  * Automated PERT/Network Diagram layout engine (`PertLayout`).
  * Integration with `LegacyGanttTask` models.
  * Custom `nodeBuilder` support for flexible UI design.
  * Zoom and pan interactions.
