import 'dart:math' as math;

import 'package:flutter/material.dart';

class TrajectoryPainter extends CustomPainter {
  TrajectoryPainter({
    required this.trajectory,
    required this.robotX,
    required this.robotY,
    required this.robotYaw,
    required this.scale,
    this.panX = 0.0,
    this.panY = 0.0,
  });

  final List<Offset> trajectory;
  final double robotX;
  final double robotY;
  final double robotYaw;
  final double scale;
  final double panX;
  final double panY;

  @override
  void paint(Canvas canvas, Size size) {
    final screenCenter = Offset(
      size.width / 2 + panX,
      size.height / 2 + panY,
    );

    _drawGrid(canvas, size, screenCenter);
    _drawAxes(canvas, size, screenCenter);
    _drawStartMarker(canvas, screenCenter);
    _drawTrajectory(canvas, screenCenter);
    _drawRobotMarker(canvas, screenCenter);
  }

  Offset _toScreen(Offset world, Offset screenCenter) {
    return Offset(
      screenCenter.dx - world.dy * scale,
      screenCenter.dy - world.dx * scale,
    );
  }

  void _drawGrid(Canvas canvas, Size size, Offset screenCenter) {
    final paint = Paint()
      ..color = const Color(0xFFE8E8ED)
      ..strokeWidth = 0.5;

    final startWx = ((screenCenter.dx - size.width) / scale).floor() - 1;
    final endWx = (screenCenter.dx / scale).ceil() + 1;
    for (var wx = startWx; wx <= endWx; wx++) {
      final sx = screenCenter.dx - wx * scale;
      if (sx < 0 || sx > size.width) continue;
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), paint);
    }

    final startWy = (-screenCenter.dy / scale).floor() - 1;
    final endWy = ((size.height - screenCenter.dy) / scale).ceil() + 1;
    for (var wy = startWy; wy <= endWy; wy++) {
      final sy = screenCenter.dy + wy * scale;
      if (sy < 0 || sy > size.height) continue;
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), paint);
    }
  }

  void _drawAxes(Canvas canvas, Size size, Offset screenCenter) {
    final paint = Paint()
      ..color = const Color(0xFFD1D1D6)
      ..strokeWidth = 1.0;

    final originScreen = _toScreen(const Offset(0, 0), screenCenter);

    if (originScreen.dy >= 0 && originScreen.dy <= size.height) {
      canvas.drawLine(
        Offset(0, originScreen.dy),
        Offset(size.width, originScreen.dy),
        paint,
      );
    }
    if (originScreen.dx >= 0 && originScreen.dx <= size.width) {
      canvas.drawLine(
        Offset(originScreen.dx, 0),
        Offset(originScreen.dx, size.height),
        paint,
      );
    }
  }

  void _drawStartMarker(Canvas canvas, Offset screenCenter) {
    final originScreen = _toScreen(const Offset(0, 0), screenCenter);

    final ringPaint = Paint()
      ..color = const Color(0xFF34C759)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(originScreen, 7.0, ringPaint);

    final dotPaint = Paint()
      ..color = const Color(0xFF34C759)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(originScreen, 2.5, dotPaint);
  }

  void _drawTrajectory(Canvas canvas, Offset screenCenter) {
    if (trajectory.length < 2) return;

    final paint = Paint()
      ..color = const Color(0xFF2563A8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (var i = 0; i < trajectory.length; i++) {
      final s = _toScreen(trajectory[i], screenCenter);
      if (i == 0) {
        path.moveTo(s.dx, s.dy);
      } else {
        path.lineTo(s.dx, s.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawRobotMarker(Canvas canvas, Offset screenCenter) {
    final robotScreen = _toScreen(Offset(robotX, robotY), screenCenter);

    final markerRadius = (scale * 0.06).clamp(3.0, 5.0);
    final arrowLen = (scale * 0.2).clamp(10.0, 18.0);
    final headSize = (arrowLen * 0.35).clamp(4.0, 6.0);

    final dirX = -math.sin(robotYaw);
    final dirY = -math.cos(robotYaw);

    final fillPaint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(robotScreen, markerRadius, fillPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(robotScreen, markerRadius, borderPaint);

    final startX = robotScreen.dx + markerRadius * dirX;
    final startY = robotScreen.dy + markerRadius * dirY;
    final endX = robotScreen.dx + arrowLen * dirX;
    final endY = robotScreen.dy + arrowLen * dirY;

    final arrowPaint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), arrowPaint);

    final perpX = -dirY;
    final perpY = dirX;

    canvas.drawPath(
      Path()
        ..moveTo(endX - perpX * headSize, endY - perpY * headSize)
        ..lineTo(endX, endY)
        ..lineTo(endX + perpX * headSize, endY + perpY * headSize),
      arrowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant TrajectoryPainter oldDelegate) {
    return oldDelegate.trajectory != trajectory ||
        oldDelegate.robotX != robotX ||
        oldDelegate.robotY != robotY ||
        oldDelegate.robotYaw != robotYaw ||
        oldDelegate.scale != scale ||
        oldDelegate.panX != panX ||
        oldDelegate.panY != panY;
  }
}
