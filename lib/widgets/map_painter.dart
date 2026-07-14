import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/map_service.dart';

/// RViz2-style occupancy grid painter.
///
/// Coordinate convention (ROS standard, top-down view):
///   world +X (forward) -> screen UP   (screen Y decreasing)
///   world +Y (left)    -> screen LEFT  (screen X decreasing)
///
/// Map grid: col -> world_x, row -> world_y
///   world_x = origin_x + col * resolution
///   world_y = origin_y + row * resolution
class OccupancyMapPainter extends CustomPainter {
  OccupancyMapPainter({
    required this.map,
    required this.mapImage,
    required this.scanPoints,
    required this.trajectory,
    required this.robotX,
    required this.robotY,
    required this.robotYaw,
    required this.scale,
    this.panX = 0.0,
    this.panY = 0.0,
  });

  final OccupancyMap? map;
  final ui.Image? mapImage;
  final List<Offset> scanPoints;
  final List<Offset> trajectory;
  final double robotX;
  final double robotY;
  final double robotYaw;
  final double scale;
  final double panX;
  final double panY;

  Offset _worldToScreen(double wx, double wy, Offset origin) {
    return Offset(
      origin.dx - wy * scale,
      origin.dy - wx * scale,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(
      size.width / 2 + panX,
      size.height / 2 + panY,
    );

    _drawMap(canvas, origin);
    _drawGrid(canvas, size, origin);
    _drawAxes(canvas, size, origin);
    _drawOriginMarker(canvas, origin);
    _drawTrajectory(canvas, origin);
    _drawScanPoints(canvas, origin);
    _drawRobot(canvas, origin);
  }

  void _drawMap(Canvas canvas, Offset origin) {
    if (mapImage == null || map == null) return;
    final m = map!;
    final cellSize = m.resolution * scale;

    final mapOriginScreenX = origin.dx - m.originY * scale;
    final mapOriginScreenY = origin.dy - m.originX * scale;

    final paint = Paint();

    canvas.save();
    canvas.translate(mapOriginScreenX, mapOriginScreenY);
    canvas.scale(-cellSize, -cellSize);
    canvas.drawImage(mapImage!, Offset.zero, paint);
    canvas.restore();
  }

  void _drawGrid(Canvas canvas, Size size, Offset origin) {
    final paint = Paint()
      ..color = const Color(0x22888888)
      ..strokeWidth = 0.5;

    final step = scale;

    final startY = ((0 - origin.dx) / step).floor() - 1;
    final endY = ((size.width - origin.dx) / step).ceil() + 1;
    for (var i = startY; i <= endY; i++) {
      final x = origin.dx + i * step;
      if (x < 0 || x > size.width) continue;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    final startX = ((0 - origin.dy) / step).floor() - 1;
    final endX = ((size.height - origin.dy) / step).ceil() + 1;
    for (var i = startX; i <= endX; i++) {
      final y = origin.dy + i * step;
      if (y < 0 || y > size.height) continue;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawAxes(Canvas canvas, Size size, Offset origin) {
    final paint = Paint()
      ..color = const Color(0x55888888)
      ..strokeWidth = 1.0;

    final worldOrigin = _worldToScreen(0, 0, origin);

    if (worldOrigin.dy >= 0 && worldOrigin.dy <= size.height) {
      canvas.drawLine(
        Offset(0, worldOrigin.dy),
        Offset(size.width, worldOrigin.dy),
        paint,
      );
    }
    if (worldOrigin.dx >= 0 && worldOrigin.dx <= size.width) {
      canvas.drawLine(
        Offset(worldOrigin.dx, 0),
        Offset(worldOrigin.dx, size.height),
        paint,
      );
    }
  }

  void _drawOriginMarker(Canvas canvas, Offset origin) {
    final p = _worldToScreen(0, 0, origin);

    canvas.drawCircle(
      p,
      7.0,
      Paint()
        ..color = const Color(0xFF34C759)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    canvas.drawCircle(
      p,
      2.5,
      Paint()..color = const Color(0xFF34C759),
    );
  }

  void _drawTrajectory(Canvas canvas, Offset origin) {
    if (trajectory.length < 2) return;

    final paint = Paint()
      ..color = const Color(0xAA2563A8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (var i = 0; i < trajectory.length; i++) {
      final s = _worldToScreen(trajectory[i].dx, trajectory[i].dy, origin);
      if (i == 0) {
        path.moveTo(s.dx, s.dy);
      } else {
        path.lineTo(s.dx, s.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawScanPoints(Canvas canvas, Offset origin) {
    if (scanPoints.isEmpty) return;

    final cosYaw = math.cos(robotYaw);
    final sinYaw = math.sin(robotYaw);

    final paint = Paint()
      ..color = const Color(0xFF34C759)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final screenPoints = <Offset>[];
    for (final p in scanPoints) {
      final wx = robotX + p.dx * cosYaw - p.dy * sinYaw;
      final wy = robotY + p.dx * sinYaw + p.dy * cosYaw;
      screenPoints.add(_worldToScreen(wx, wy, origin));
    }
    canvas.drawPoints(ui.PointMode.points, screenPoints, paint);
  }

  void _drawRobot(Canvas canvas, Offset origin) {
    final robotScreen = _worldToScreen(robotX, robotY, origin);

    final markerRadius = (scale * 0.08).clamp(4.0, 7.0);
    final arrowLen = (scale * 0.25).clamp(12.0, 24.0);
    final headSize = (arrowLen * 0.35).clamp(4.0, 7.0);

    final dirX = -math.sin(robotYaw);
    final dirY = -math.cos(robotYaw);

    canvas.drawCircle(
      robotScreen,
      markerRadius,
      Paint()
        ..color = const Color(0xFFD32F2F)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      robotScreen,
      markerRadius,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

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
  bool shouldRepaint(covariant OccupancyMapPainter old) {
    return old.mapImage != mapImage ||
        old.map != map ||
        old.scanPoints != scanPoints ||
        old.trajectory != trajectory ||
        old.robotX != robotX ||
        old.robotY != robotY ||
        old.robotYaw != robotYaw ||
        old.scale != scale ||
        old.panX != panX ||
        old.panY != panY;
  }
}
