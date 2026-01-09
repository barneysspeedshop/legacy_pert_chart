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
