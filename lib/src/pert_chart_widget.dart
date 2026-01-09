import 'package:flutter/material.dart';
import 'package:legacy_pert_chart/src/models/pert_task.dart';
import 'package:legacy_pert_chart/src/pert_layout.dart';
import 'package:legacy_pert_chart/src/pert_painter.dart';

/// A function signature for building custom task nodes.
///
/// * [context]: The build context.
/// * [task]: The task being rendered.
/// * [size]: The standard size of the node (width, height) allocated by the layout.
typedef PertNodeBuilder = Widget? Function(
    BuildContext context, LegacyPertTask task, Size size);

/// A widget that displays a PERT (Program Evaluation and Review Technique) chart.
///
/// This widget takes a list of [LegacyPertTask]s and automatically arranges them
/// using the [PertLayout] engine. It renders nodes using a default look or a
/// custom [nodeBuilder], and connects them with directed arrows.
///
/// The chart is wrapped in an [InteractiveViewer], allowing for zooming and panning.
class LegacyPertChartWidget extends StatefulWidget {
  /// The list of tasks to display in the chart.
  final List<LegacyPertTask> tasks;

  /// An optional builder for rendering custom nodes.
  ///
  /// If provided, this function is called for each task. If it returns `null`,
  /// the default node style is used for that specific task.
  final PertNodeBuilder? nodeBuilder;

  /// The color of the dependency links (arrows).
  ///
  /// Defaults to [Colors.black54] (light mode) or [Colors.white54] (dark mode) if null.
  final Color? linkColor;

  /// The stroke width of the dependency links.
  ///
  /// Defaults to 2.0.
  final double? linkWidth;

  /// Creates a [LegacyPertChartWidget].
  ///
  /// * [tasks]: The data to visualize.
  /// * [nodeBuilder]: Optional custom renderer for nodes.
  /// * [linkColor]: Optional color override for edges.
  /// * [linkWidth]: Optional width override for edges.
  const LegacyPertChartWidget({
    super.key,
    required this.tasks,
    this.nodeBuilder,
    this.linkColor,
    this.linkWidth,
    this.onDependencyAdded,
    this.onNodeTap,
  });

  /// Callback when a user drags a connection from one node to another.
  ///
  /// * [fromId]: The ID of the source task.
  /// * [toId]: The ID of the target task.
  final void Function(String fromId, String toId)? onDependencyAdded;

  /// Callback when a user taps on a node.
  final void Function(LegacyPertTask task)? onNodeTap;

  @override
  State<LegacyPertChartWidget> createState() => _LegacyPertChartWidgetState();
}

class _LegacyPertChartWidgetState extends State<LegacyPertChartWidget> {
  late PertLayout _layout;
  late ({Map<String, Offset> positions, Size size}) _layoutResult;

  String? _dragSourceId;
  Offset? _dragCurrentPos;

  @override
  void initState() {
    super.initState();
    _layout = PertLayout();
    _calculateLayout();
  }

  @override
  void didUpdateWidget(covariant LegacyPertChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks != widget.tasks) {
      _calculateLayout();
    }
  }

  void _calculateLayout() {
    _layoutResult = _layout.calculateLayout(widget.tasks);
  }

  @override
  Widget build(BuildContext context) {
    final size = _layoutResult.size;
    final effectiveSize = size.isEmpty ? const Size(100, 100) : size;
    final positions = _layoutResult.positions;

    // Theme awareness
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;

    final defaultLinkColor = isDark ? Colors.white54 : Colors.black54;
    final effectiveLinkColor = widget.linkColor ?? defaultLinkColor;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(double.infinity),
        minScale: 0.1,
        maxScale: 4.0,
        constrained: false,
        child: SizedBox(
          width: effectiveSize.width,
          height: effectiveSize.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: PertPainter(
                    tasks: widget.tasks,
                    positions: positions,
                    linkColor: effectiveLinkColor,
                    linkWidth: widget.linkWidth ?? 2.0,
                    dragSource:
                        _dragSourceId != null ? positions[_dragSourceId] : null,
                    dragTarget: _dragCurrentPos,
                  ),
                ),
              ),
              ...widget.tasks.map((task) {
                if (!positions.containsKey(task.id)) {
                  return const SizedBox.shrink();
                }
                final center = positions[task.id]!;
                const w = PertLayout.nodeWidth;
                const h = PertLayout.nodeHeight;

                return Positioned(
                  left: center.dx - w / 2,
                  top: center.dy - h / 2,
                  width: w,
                  height: h,
                  child: GestureDetector(
                    onTap: () => widget.onNodeTap?.call(task),
                    onPanStart: (details) {
                      setState(() {
                        _dragSourceId = task.id;
                        // Initial position is exact touch point
                        // TopLeft of node = center - w/2, h/2
                        final nodeTopLeft = center - const Offset(w / 2, h / 2);
                        _dragCurrentPos = nodeTopLeft + details.localPosition;
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        // Update relative to widget local position would be tricky if we don't track start.
                        // Simpler: Just add delta to current.
                        if (_dragCurrentPos != null) {
                          _dragCurrentPos = _dragCurrentPos! + details.delta;
                        }
                      });
                    },
                    onPanEnd: (details) {
                      // Hit test
                      if (_dragSourceId != null && _dragCurrentPos != null) {
                        final dropPos = _dragCurrentPos!;
                        String? targetId;

                        // Check all other nodes
                        for (var entry in positions.entries) {
                          if (entry.key == _dragSourceId) continue;

                          final p = entry.value;
                          // Simple bounding box check
                          if (dropPos.dx >= p.dx - w / 2 &&
                              dropPos.dx <= p.dx + w / 2 &&
                              dropPos.dy >= p.dy - h / 2 &&
                              dropPos.dy <= p.dy + h / 2) {
                            targetId = entry.key;
                            break;
                          }
                        }

                        if (targetId != null) {
                          widget.onDependencyAdded
                              ?.call(_dragSourceId!, targetId);
                        }
                      }

                      setState(() {
                        _dragSourceId = null;
                        _dragCurrentPos = null;
                      });
                    },
                    child: widget.nodeBuilder
                            ?.call(context, task, const Size(w, h)) ??
                        _buildDefaultNode(context, task, const Size(w, h)),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultNode(
      BuildContext context, LegacyPertTask task, Size size) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final color = isDark ? Colors.grey[800]! : Colors.blue[100]!;
    final borderColor = isDark ? Colors.grey[600]! : Colors.blue[800]!;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            task.name,
            style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ) ??
                TextStyle(color: textColor, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (task.duration != null)
            Text(
              '${task.duration!.inHours}h',
              style: theme.textTheme.bodySmall
                      ?.copyWith(color: textColor.withValues(alpha: 0.8)) ??
                  TextStyle(
                      color: textColor.withValues(alpha: 0.8), fontSize: 12),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
