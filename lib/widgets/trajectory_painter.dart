import 'dart:math' as math;

import 'package:flutter/material.dart';

class TrajectoryPainter extends CustomPainter {
  TrajectoryPainter({
    required this.trajectory,
    required this.robotX,
    required this.robotY,
    required this.robotYaw,
    required this.scale,
  });

  final List<Offset> trajectory;
  final double robotX;
  final double robotY;
  final double robotYaw;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    _drawGrid(canvas, size, center);
    _drawAxes(canvas, size, center);
    _drawTrajectory(canvas, center);
    _drawRobotMarker(canvas, center);
  }

  void _drawGrid(Canvas canvas, Size size, Offset center) {
    final paint = Paint()
      ..color = const Color(0xFFE8E8ED)
      ..strokeWidth = 0.5;

    final step = scale;
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

  void _drawTrajectory(Canvas canvas, Offset center) {
    if (trajectory.length < 2) return;

    final paint = Paint()
      ..color = const Color(0xFF2563A8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (var i = 0; i < trajectory.length; i++) {
      final p = trajectory[i];
      final sx = center.dx - (p.dy - robotY) * scale;
      final sy = center.dy - (p.dx - robotX) * scale;
      if (i == 0) {
        path.moveTo(sx, sy);
      } else {
        path.lineTo(sx, sy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawRobotMarker(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 6.0, paint);

    final arrowLength = 14.0;
    final dx = -arrowLength * math.sin(robotYaw);
    final dy = -arrowLength * math.cos(robotYaw);

    final arrowPaint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      center,
      Offset(center.dx + dx, center.dy + dy),
      arrowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant TrajectoryPainter oldDelegate) {
    return oldDelegate.trajectory != trajectory ||
        oldDelegate.robotX != robotX ||
        oldDelegate.robotY != robotY ||
        oldDelegate.robotYaw != robotYaw ||
        oldDelegate.scale != scale;
  }
}
