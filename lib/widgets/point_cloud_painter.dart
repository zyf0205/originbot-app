import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

class PointCloudPainter extends CustomPainter {
  PointCloudPainter({
    required this.points,
    required this.scale,
    required this.rangeMin,
    required this.rangeMax,
  });

  final List<Offset> points;
  final double scale;
  final double rangeMin;
  final double rangeMax;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    _drawGrid(canvas, size, center);
    _drawRangeCircles(canvas, center);
    _drawAxes(canvas, size, center);
    _drawRobotMarker(canvas, center);
    _drawPoints(canvas, center);
  }

  void _drawGrid(Canvas canvas, Size size, Offset center) {
    final paint = Paint()
      ..color = const Color(0xFFE8E8ED)
      ..strokeWidth = 0.5;

    final step = scale; // 1 米一格
    for (var i = -20; i <= 20; i++) {
      final x = center.dx + i * step;
      if (x < 0 || x > size.width) continue;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var i = -20; i <= 20; i++) {
      final y = center.dy + i * step;
      if (y < 0 || y > size.height) continue;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawRangeCircles(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = const Color(0x42000000)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (final r in [1.0, 2.0, 3.0, 5.0, 10.0]) {
      if (rangeMax > 0 && r > rangeMax) break;
      canvas.drawCircle(center, r * scale, paint);
    }
  }

  void _drawAxes(Canvas canvas, Size size, Offset center) {
    final paint = Paint()
      ..color = const Color(0xFFD1D1D6)
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      paint,
    );
  }

  void _drawRobotMarker(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = const Color(0xFF2563A8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 5.0, paint);

    final arrowPaint = Paint()
      ..color = const Color(0xFF2563A8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    // Arrow starts from circle edge (radius=5), not from center
    final path = Path()
      ..moveTo(center.dx, center.dy - 5.0)
      ..lineTo(center.dx, center.dy - 12);
    canvas.drawPath(path, arrowPaint);

    canvas.drawPath(
      Path()
        ..moveTo(center.dx - 4, center.dy - 8)
        ..lineTo(center.dx, center.dy - 12)
        ..lineTo(center.dx + 4, center.dy - 8),
      Paint()
        ..color = const Color(0xFF2563A8)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawPoints(Canvas canvas, Offset center) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = const Color(0xFF34C759)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final screenPoints = <Offset>[];
    for (final p in points) {
      // X(前方) → 屏幕上方, Y(左方) → 屏幕左方
      final screenX = center.dx - p.dy * scale;
      final screenY = center.dy - p.dx * scale;
      screenPoints.add(Offset(screenX, screenY));
    }
    canvas.drawPoints(PointMode.points, screenPoints, paint);
  }

  @override
  bool shouldRepaint(covariant PointCloudPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.scale != scale ||
        oldDelegate.rangeMin != rangeMin ||
        oldDelegate.rangeMax != rangeMax;
  }
}
