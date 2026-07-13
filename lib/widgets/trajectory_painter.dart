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
    final viewCenterX =
        trajectory.isEmpty ? robotX : _centroid(trajectory, (p) => p.dx);
    final viewCenterY =
        trajectory.isEmpty ? robotY : _centroid(trajectory, (p) => p.dy);

    final viewCenterScreen = Offset(size.width / 2, size.height / 2);

    _drawGrid(canvas, size, viewCenterScreen, viewCenterX, viewCenterY);
    _drawAxes(canvas, size, viewCenterScreen, viewCenterX, viewCenterY);
    _drawTrajectory(canvas, viewCenterScreen, viewCenterX, viewCenterY);
    _drawRobotMarker(canvas, viewCenterScreen, viewCenterX, viewCenterY);
  }

  double _centroid(List<Offset> pts, double Function(Offset) coord) {
    var sum = 0.0;
    for (final p in pts) {
      sum += coord(p);
    }
    return sum / pts.length;
  }

  Offset _toScreen(
    Offset world,
    Offset screenCenter,
    double viewCenterX,
    double viewCenterY,
  ) {
    return Offset(
      screenCenter.dx - (world.dy - viewCenterY) * scale,
      screenCenter.dy - (world.dx - viewCenterX) * scale,
    );
  }

  void _drawGrid(
    Canvas canvas,
    Size size,
    Offset screenCenter,
    double viewCenterX,
    double viewCenterY,
  ) {
    final paint = Paint()
      ..color = const Color(0xFFE8E8ED)
      ..strokeWidth = 0.5;

    final startWorldX = viewCenterX - size.width / 2 / scale;
    final endWorldX = viewCenterX + size.width / 2 / scale;
    final startWorldY = viewCenterY - size.height / 2 / scale;
    final endWorldY = viewCenterY + size.height / 2 / scale;

    for (var wx = startWorldX.floor(); wx <= endWorldX.ceil(); wx++) {
      final sx = screenCenter.dx - (wx - viewCenterX) * scale;
      if (sx < 0 || sx > size.width) continue;
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), paint);
    }
    for (var wy = startWorldY.floor(); wy <= endWorldY.ceil(); wy++) {
      final sy = screenCenter.dy + (wy - viewCenterY) * scale;
      if (sy < 0 || sy > size.height) continue;
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), paint);
    }
  }

  void _drawAxes(
    Canvas canvas,
    Size size,
    Offset screenCenter,
    double viewCenterX,
    double viewCenterY,
  ) {
    final paint = Paint()
      ..color = const Color(0xFFD1D1D6)
      ..strokeWidth = 1.0;

    final originScreen = _toScreen(
      const Offset(0, 0),
      screenCenter,
      viewCenterX,
      viewCenterY,
    );

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

  void _drawTrajectory(
    Canvas canvas,
    Offset screenCenter,
    double viewCenterX,
    double viewCenterY,
  ) {
    if (trajectory.length < 2) return;

    final paint = Paint()
      ..color = const Color(0xFF2563A8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (var i = 0; i < trajectory.length; i++) {
      final s =
          _toScreen(trajectory[i], screenCenter, viewCenterX, viewCenterY);
      if (i == 0) {
        path.moveTo(s.dx, s.dy);
      } else {
        path.lineTo(s.dx, s.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawRobotMarker(
    Canvas canvas,
    Offset screenCenter,
    double viewCenterX,
    double viewCenterY,
  ) {
    final robotScreen = _toScreen(
      Offset(robotX, robotY),
      screenCenter,
      viewCenterX,
      viewCenterY,
    );

    final markerRadius = (scale * 0.08).clamp(3.0, 6.0);
    final arrowLen = (scale * 0.2).clamp(8.0, 16.0);

    final fillPaint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(robotScreen, markerRadius, fillPaint);

    final dirX = -math.sin(robotYaw);
    final dirY = -math.cos(robotYaw);

    final startX = robotScreen.dx + markerRadius * dirX;
    final startY = robotScreen.dy + markerRadius * dirY;
    final endX = robotScreen.dx + arrowLen * dirX;
    final endY = robotScreen.dy + arrowLen * dirY;

    final arrowPaint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), arrowPaint);

    final perpX = -dirY;
    final perpY = dirX;
    final headSize = (arrowLen * 0.35).clamp(3.0, 5.0);

    canvas.drawPath(
      Path()
        ..moveTo(endX - perpX * headSize, endY - perpY * headSize)
        ..lineTo(endX, endY)
        ..lineTo(endX + perpX * headSize, endY + perpY * headSize),
      Paint()
        ..color = const Color(0xFFD32F2F)
        ..style = PaintingStyle.fill,
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
