import 'package:legacy_gantt_chart/legacy_gantt_chart.dart';

/// A task (node) in the PERT chart.
///
/// This serves as the fundamental unit for the Network Diagram. It represents an
/// activity or event. While similar to [LegacyGanttTask], this model is optimized
/// for network-style visualizations where relationships and critical paths are
/// emphasized over timeline scheduling.
class LegacyPertTask {
  /// The unique identifier for this task.
  final String id;

  /// The display name of the task.
  final String name;

  /// A list of IDs representing tasks that must complete before this one can start.
  final List<String> dependencyIds;

  /// An optional ID used to group tasks into horizontal "lanes" or "swimlanes"
  /// during layout.
  final String? laneId;

  /// Whether this task lies on the critical path.
  ///
  /// Critical tasks are typically highlighted (e.g., with red borders) to indicate
  /// that any delay in them will delay the entire project.
  final bool isCritical;

  /// The estimated or actual duration of the task.
  ///
  /// If provided, this can be displayed within the node to give context on
  /// effort or time required.
  final Duration? duration;

  // PERT-specific estimates could be added here:
  // final Duration optimisticDuration;
  // final Duration pessimisticDuration;
  // final Duration mostLikelyDuration;

  /// Creates a [LegacyPertTask].
  ///
  /// * [id]: Unique identifier.
  /// * [name]: Display label.
  /// * [dependencyIds]: IDs of predecessor tasks.
  /// * [laneId]: Optional grouping identifier.
  /// * [isCritical]: Highlights usage in critical path calculation.
  /// * [duration]: Optional duration metadata.
  const LegacyPertTask({
    required this.id,
    required this.name,
    this.dependencyIds = const [],
    this.laneId,
    this.isCritical = false,
    this.duration,
  });
}
