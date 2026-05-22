// lib/widgets/arrow_painter.dart
//
// CustomPainter that draws a white directional arrow centered on the canvas.
// Rotate by [angleDegrees] to point toward the target plant.
//
// Usage:
//   CustomPaint(
//     painter: ArrowPainter(angleDegrees: arrowAngle),
//     size: const Size(120, 120),
//   )
//
// The angle passed here is pre-computed in the provider as:
//   arrowAngle = navigationState.bearing - deviceCompassHeading
// Do NOT recompute it here.

import 'dart:math' as math;
import 'package:flutter/material.dart';

class ArrowPainter extends CustomPainter {
  const ArrowPainter({required this.angleDegrees});

  /// Clockwise rotation in degrees. 0 = pointing up (north).
  final double angleDegrees;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) * 0.85;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angleDegrees * math.pi / 180);

    // ── Shadow ────────────────────────────────────────────────────────────────
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha((0.35 * 255).round())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    _drawArrowPath(canvas, radius, shadowPaint, offset: const Offset(3, 3));

    // ── Arrow fill ────────────────────────────────────────────────────────────
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    _drawArrowPath(canvas, radius, fillPaint);

    // ── Arrow stroke ──────────────────────────────────────────────────────────
    final strokePaint = Paint()
      ..color = Colors.white.withAlpha((0.6 * 255).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    _drawArrowPath(canvas, radius, strokePaint);

    canvas.restore();
  }

  void _drawArrowPath(
    Canvas canvas,
    double radius,
    Paint paint, {
    Offset offset = Offset.zero,
  }) {
    final arrowWidth = radius * 0.38;
    final arrowTip = -radius;          // tip points up (north before rotation)
    final arrowBase = radius * 0.45;   // flat bottom of the shaft
    final notchDepth = radius * 0.25;  // V-notch depth at the tail

    final path = Path()
      ..moveTo(offset.dx, offset.dy + arrowTip)                            // tip
      ..lineTo(offset.dx + arrowWidth, offset.dy + arrowBase)              // bottom-right
      ..lineTo(offset.dx, offset.dy + arrowBase - notchDepth)              // notch centre
      ..lineTo(offset.dx - arrowWidth, offset.dy + arrowBase)              // bottom-left
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ArrowPainter oldDelegate) =>
      oldDelegate.angleDegrees != angleDegrees;
}
