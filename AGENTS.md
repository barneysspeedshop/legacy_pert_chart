# AI Agent Instructions for Legacy PERT Chart

This directory contains the `legacy_pert_chart` package, a Flutter widget for visualizing task dependency networks as PERT (Program Evaluation and Review Technique) / Network Diagrams. The layout is computed entirely on-device by the `PertLayout` engine — no backend service is involved.

## The Fragile Core: `PertLayout` Ranking Algorithm

`PertLayout` (in `lib/src/pert_layout.dart`) is the heart of this package. It is the only component that determines where nodes appear on screen. All rendering in `PertPainter` and `LegacyPertChartWidget` is downstream of its output. Treat it as fragile.

### Inputs

`PertLayout.calculateLayout()` accepts a `List<LegacyPertTask>`. Each task carries:

| Field | Type | Role in layout |
|---|---|---|
| `id` | `String` | Node identity; used as the key in all output maps |
| `dependencyIds` | `List<String>` | Directed edges: predecessors that must appear to the left |
| `laneId` | `String?` | Swimlane grouping; tasks with the same `laneId` share a horizontal band |
| `isCritical` | `bool` | Gives the task priority for the center row (Row 0) within its lane/rank cell |
| `duration` | `Duration?` | Metadata only — not used by the layout algorithm |

> [!IMPORTANT]
> A task referenced in `dependencyIds` that does not appear in the input list is treated as a **ghost task**. Ghost tasks receive rank 0 and are silently skipped during position assignment. This is intentional but means dangling dependency IDs produce no error — they are silently ignored.

### Outputs

`calculateLayout()` returns a Dart record:

```dart
({Map<String, Offset> positions, Size size})
```

- **`positions`**: Maps each task `id` to the **center** `Offset` of its node in canvas coordinates. The widget layer uses this to position `Positioned` children; the painter uses it to draw edges. Both consumers assume center-based coordinates — do not change this convention.
- **`size`**: The total bounding box of the diagram. Used by `LegacyPertChartWidget` to size the `SizedBox` inside `InteractiveViewer`.

### Algorithm: Two-Phase Rank + Lane Layout

**Phase 1 — Rank assignment (`_calculateRanks`)**

Rank determines the X-axis column (left-to-right flow). It is computed by a recursive DFS with memoization:

```
rank(task) = max(rank(dep) for dep in dependencyIds) + 1
```

An implicit rule also applies: if a task has a `laneId` that matches another task's `id` (i.e., the lane header is itself a task), the lane-header task's rank is treated as an additional predecessor. This enforces that all lane members appear to the right of their lane header.

**Cycle handling**: The algorithm detects cycles via a `visiting` set. When a cycle is detected, the offending node falls back to rank 0. This is a silent fallback — no exception is thrown and no warning is emitted.

**Phase 2 — Lane and row assignment**

Within each rank column, tasks are grouped by `laneId`. Inside each lane/rank cell, tasks are assigned vertical rows using a **spiral pattern** centered on Row 0:

```
i=0 → row 0   (critical task, if any, is sorted first)
i=1 → row +1
i=2 → row -1
i=3 → row +2
i=4 → row -2
...
```

Lane heights are computed from the min/max row extents across all rank columns for that lane. The Y coordinate of each node is:

```
y = laneCenterY[laneId] + row * (nodeHeight + nodeSpacing)
```

X coordinates are rank-based, computed by iterating a running `currentX` cursor:

```
rankX[r] = currentX + nodeWidth / 2
currentX += nodeWidth + rankSpacing   // rankSpacing = 200.0
```

The initial `currentX` starts at 50.0 (left padding). This means the X position of rank `r` is not a simple closed-form expression — it depends on the cumulative widths of all preceding ranks. Currently all ranks have the same width, so the effective formula is `50.0 + r * (nodeWidth + rankSpacing) + nodeWidth / 2`, but if per-rank widths are ever made variable, the cursor-based approach will diverge from a closed-form calculation.

### Performance Characteristics

- **Time complexity**: O(N + E) for rank calculation (DFS with memoization), where N = number of tasks and E = number of dependency edges. The lane/row assignment pass is O(N log N) due to per-cell sorting.
- **Space complexity**: O(N) for the rank map, visited sets, and row assignment maps.
- **Recalculation**: Layout is recalculated in full on every `didUpdateWidget` call when `tasks` changes (reference inequality check). There is no incremental update or diffing. For large graphs (thousands of nodes), this full recalculation happens synchronously on the UI thread.

> [!WARNING]
> `calculateLayout()` runs synchronously on the UI thread. For task lists exceeding a few hundred nodes, this can cause frame drops. There is currently no async or isolate-based path. Do not call `calculateLayout()` inside `build()` — it is called once in `_calculateLayout()` and cached in `_layoutResult`.

---

## Fragile Areas

### 1. Cycle Detection Silently Falls Back to Rank 0

The `_calculateRanks` DFS detects cycles via the `visiting` set and returns rank 0 for any node involved in a cycle. **No exception is thrown and no warning is logged.** A cyclic dependency graph will produce a layout that appears to work but places all cycle participants at rank 0, causing them to overlap in the leftmost column. If you add cycle detection or reporting, do it inside `_calculateRanks` before the fallback return.

### 2. Ghost Tasks Are Silently Skipped

If `dependencyIds` references an ID not present in the input `tasks` list, that ID is assigned rank 0 in `_calculateRanks` (the `task == null` branch), but it is never added to `positions`. The downstream position assignment loop skips any task whose ID is absent from `positions`. This means a task whose only predecessor is a ghost will be placed at rank 1 with no visible incoming edge. There is no validation or warning.

### 3. `laneId` Doubles as a Parent Task ID

The implicit rule in `_calculateRanks` treats `laneId` as a predecessor task ID when `laneId != taskId` and `taskMap.containsKey(laneId)`. This means if you set `laneId` to an arbitrary string that happens to match another task's `id`, that task will be treated as a layout predecessor. This is intentional but non-obvious — document it when adding new tasks programmatically.

### 4. Layout Is Not Incremental

`LegacyPertChartWidget.didUpdateWidget` triggers a full `_calculateLayout()` call whenever `widget.tasks != oldWidget.tasks` (reference inequality). Passing a new `List` instance with the same contents on every rebuild will cause unnecessary full recalculations. Callers should stabilize the `tasks` reference (e.g., store it in state or a `ValueNotifier`) to avoid redundant layout passes.

### 5. `PertPainter.shouldRepaint` Uses Reference Equality

`PertPainter.shouldRepaint` compares `tasks` and `positions` by reference (`!=`). Since `positions` is a new `Map` instance on every `calculateLayout()` call, the painter always repaints after a layout recalculation. This is correct behavior but means painting cost is always paid after any task list change — there is no short-circuit for visually identical layouts.

### 7. `PertLayout` Is Not Part of the Public API

`lib/legacy_pert_chart.dart` exports only `LegacyPertTask` and `LegacyPertChartWidget`. `PertLayout` itself is **not exported**. Callers cannot instantiate `PertLayout` directly from outside the package. If you need to expose layout calculation as a public API (e.g., for custom rendering), you must add an explicit export to `lib/legacy_pert_chart.dart`.

### 8. Interactive Dependency Editing Callbacks

`LegacyPertChartWidget` exposes two interaction callbacks that are not part of the layout engine but affect widget behavior:

- `onDependencyAdded(String fromId, String toId)` — fired when the user drags from one node's edge to another node. The widget does **not** mutate the task list itself; the caller is responsible for updating state and passing a new `tasks` list.
- `onNodeTap(LegacyPertTask task)` — fired on a simple tap. No default behavior.

Both are optional (`null` by default). The drag-to-connect gesture uses a simple bounding-box hit test against `positions` — it does not use Flutter's gesture arena, so it may conflict with `InteractiveViewer` pan gestures on touch devices.

### 6. Node Size Constants Are Global and Fixed

`PertLayout.nodeWidth` (120.0) and `PertLayout.nodeHeight` (60.0) are `static const` values shared by `PertLayout`, `PertPainter`, and `LegacyPertChartWidget`. If you change these constants, you must audit all three files — the painter uses them for edge intersection math (`_getIntersection`), and the widget uses them for `Positioned` child placement. Mismatches between the layout engine's assumed node size and the painter's assumed node size will cause arrows to miss node boundaries.
