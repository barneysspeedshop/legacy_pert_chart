import 'dart:math';
import 'package:flutter/material.dart';
import 'models/pert_task.dart';
import 'pert_layout.dart';

/// A [CustomPainter] that draws the connecting lines (edges) between PERT nodes.
///
/// It iterates through all tasks and their dependencies, drawing straight lines
/// with arrowheads connecting the source node to the target node.
class PertPainter extends CustomPainter {
  /// The list of tasks (nodes) to visualize.
  final List<LegacyPertTask> tasks;

  /// A map of task IDs to their computed center [Offset] positions.
  final Map<String, Offset> positions;

  /// The color used for the connection lines and arrowheads.
  final Color linkColor;

  /// The stroke width of the connection lines.
  final double linkWidth;

  /// Creates a [PertPainter].
  ///
  /// * [tasks]: The snapshot of tasks to draw.
  /// * [positions]: Pre-calculated positions from [PertLayout].
  /// * [linkColor]: The color of the edges (default: [Colors.grey]).
  /// * [linkWidth]: The thickness of the edges (default: 2.0).
  PertPainter({
    required this.tasks,
    required this.positions,
    this.linkColor = Colors.grey,
    this.linkWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = linkColor
      ..strokeWidth = linkWidth
      ..style = PaintingStyle.stroke;

    // Draw edges
    for (var task in tasks) {
      if (!positions.containsKey(task.id)) continue;
      final endPos = positions[task.id]!;
      // An arrow should point TO the current task FROM its dependency

      for (var depId in task.dependencyIds) {
        if (!positions.containsKey(depId)) continue;
        final startPos = positions[depId]!;

        _drawArrow(canvas, startPos, endPos, paintLine);
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    const w = PertLayout.nodeWidth;
    const h = PertLayout.nodeHeight;

    final p1 = _getIntersection(start, end, w, h);
    final p2 = _getIntersection(end, start, w, h);

    // If points are too close (inside the gap), don't draw
    if ((p1 - p2).distance < 5.0) return;

    canvas.drawLine(p1, p2, paint);

    _drawArrowHead(canvas, p1, p2, paint);
  }

  Offset _getIntersection(Offset center, Offset target, double w, double h) {
    final dx = target.dx - center.dx;
    final dy = target.dy - center.dy;

    if (dx == 0 && dy == 0) return center;

    // Calculate intersection with the box centered at 'center' with size w, h
    // Half dimensions
    final hw = w / 2.0;
    final hh = h / 2.0;

    // Determine which side is hit
    // Simple ray casting against AABB
    // tNear is the time to hit the box boundaries
    // We want the point on the boundary towards the target.

    // A simpler approach for center-to-center ray:
    // Scale the vector (dx, dy) so it hits the boundary.
    // We basically want to clamp the slope.

    double scaleX = double.infinity;
    double scaleY = double.infinity;

    if (dx != 0) scaleX = (hw / dx).abs();
    if (dy != 0) scaleY = (hh / dy).abs();

    final scale = min(scaleX, scaleY);

    // Padding away from the box
    const padding = 5.0;

    // Normalize direction
    final dist = sqrt(dx * dx + dy * dy);
    final ux = dx / dist;
    final uy = dy / dist;

    // The intersection point on the box boundary
    final ix = center.dx + dx * scale;
    final iy = center.dy + dy * scale;

    // Add padding
    return Offset(ix + ux * padding, iy + uy * padding);
  }

  void _drawArrowHead(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final arrowSize = 10.0;
    final angle = 3.14159 / 6; // 30 degrees

    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = sqrt(dx * dx + dy * dy);

    if (dist == 0) return;

    final ux = dx / dist;
    final uy = dy / dist;

    // Back vector
    final bx = -ux;
    final by = -uy;

    // Let's stick to the previous correct math logic refactored:
    // rotate(v, alpha): x' = x cos a - y sin a, y' = x sin a + y cos a

    final r1x = bx * cos(angle) - by * sin(angle);
    final r1y = bx * sin(angle) + by * cos(angle);

    final r2x = bx * cos(-angle) - by * sin(-angle);
    final r2y = bx * sin(-angle) + by * cos(-angle);

    final arrow1 = Offset(p2.dx + r1x * arrowSize, p2.dy + r1y * arrowSize);
    final arrow2 = Offset(p2.dx + r2x * arrowSize, p2.dy + r2y * arrowSize);

    final path = Path()
      ..moveTo(p2.dx, p2.dy)
      ..lineTo(arrow1.dx, arrow1.dy)
      ..lineTo(arrow2.dx, arrow2.dy)
      ..close();

    canvas.drawPath(path, paint..style = PaintingStyle.fill);
    paint.style = PaintingStyle.stroke;
  }

  @override
  bool shouldRepaint(covariant PertPainter oldDelegate) {
    return oldDelegate.tasks != tasks || oldDelegate.positions != positions;
  }
}
