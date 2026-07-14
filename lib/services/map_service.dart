import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show Offset;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/robot_status.dart';
import 'lidar_service.dart';

class OccupancyMap {
  final int width;
  final int height;
  final double resolution;
  final double originX;
  final double originY;
  final Uint8List grid;

  OccupancyMap({
    required this.width,
    required this.height,
    required this.resolution,
    required this.originX,
    required this.originY,
    required this.grid,
  });

  int cellAt(int col, int row) => grid[row * width + col];
}

class MapService extends ChangeNotifier {
  MapService(this.status, this.lidar);

  final RobotStatus status;
  final LidarService lidar;

  WebSocketChannel? _channel;
  bool _disposed = false;
  String _ip = '';
  int _imageGenId = 0;

  OccupancyMap? currentMap;
  ui.Image? mapImage;

  double correctionX = 0.0;
  double correctionY = 0.0;
  double correctionYaw = 0.0;
  bool hasCorrection = false;

  double get correctedX {
    if (!hasCorrection) return status.odomX;
    final c = math.cos(correctionYaw);
    final s = math.sin(correctionYaw);
    return status.odomX * c - status.odomY * s + correctionX;
  }

  double get correctedY {
    if (!hasCorrection) return status.odomY;
    final c = math.cos(correctionYaw);
    final s = math.sin(correctionYaw);
    return status.odomX * s + status.odomY * c + correctionY;
  }

  double get correctedYaw =>
      hasCorrection ? status.odomYaw + correctionYaw : status.odomYaw;

  static final _colorTable = List<ui.Color>.generate(256, (v) {
    if (v == 0) return const ui.Color(0x00000000);
    if (v == 255) return const ui.Color(0xFFE8E8E8);
    if (v >= 100) return const ui.Color(0xFF1A1A1A);
    final gray = 230 - (v * 1.8).round();
    return ui.Color.fromARGB(255, gray, gray, gray);
  });

  void setIp(String ip) {
    _ip = ip.trim();
  }

  Future<void> connect() async {
    if (_ip.isEmpty) return;
    if (status.mapStatus == ConnectionStatus.connecting) return;
    _channel?.sink.close();
    _channel = null;
    currentMap = null;
    mapImage?.dispose();
    mapImage = null;
    correctionX = 0.0;
    correctionY = 0.0;
    correctionYaw = 0.0;
    hasCorrection = false;
    status.updateMapStatus(ConnectionStatus.connecting);
    try {
      final uri = Uri.parse('ws://$_ip:9090/map');
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('地图连接超时(5s)，请检查 /map 端点'),
      );
      status.updateMapStatus(ConnectionStatus.connected);
      _channel!.stream.listen(
        _onMessage,
        onError: (_) => _onDisconnect(),
        onDone: _onDisconnect,
      );
    } catch (e) {
      status.mapErrorMsg = e.toString();
      status.updateMapStatus(ConnectionStatus.error);
    }
  }

  void _onMessage(dynamic data) {
    if (data is! List<int>) return;
    _parseMapFrame(Uint8List.fromList(data));
    notifyListeners();
  }

  void _parseMapFrame(Uint8List data) {
    final nullIdx = data.indexOf(0);
    if (nullIdx < 0) return;

    try {
      final headerStr = utf8.decode(data.sublist(0, nullIdx));
      final header = jsonDecode(headerStr) as Map<String, dynamic>;

      final width = header['width'] as int;
      final height = header['height'] as int;
      final resolution = (header['resolution'] as num).toDouble();
      final originX = (header['origin_x'] as num).toDouble();
      final originY = (header['origin_y'] as num).toDouble();

      Uint8List grid;
      if (header['compressed'] == true) {
        final compressed = data.sublist(nullIdx + 1);
        grid = Uint8List.fromList(ZLibDecoder().decodeBytes(compressed));
      } else {
        grid = Uint8List.fromList(data.sublist(nullIdx + 1));
      }

      final expectedGridLen = width * height;
      if (grid.length < expectedGridLen) return;

      currentMap = OccupancyMap(
        width: width,
        height: height,
        resolution: resolution,
        originX: originX,
        originY: originY,
        grid: grid,
      );

      _regenerateImage();
      _runScanMatcher();
    } catch (_) {}
  }

  Future<void> _regenerateImage() async {
    if (currentMap == null) return;
    final m = currentMap!;
    final genId = ++_imageGenId;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..style = ui.PaintingStyle.fill;

    final pathsByValue = <int, ui.Path>{};
    for (var row = 0; row < m.height; row++) {
      for (var col = 0; col < m.width; col++) {
        final v = m.grid[row * m.width + col];
        if (v == 0) continue;
        pathsByValue
            .putIfAbsent(v, () => ui.Path())
            .addRect(ui.Rect.fromLTWH(row.toDouble(), col.toDouble(), 1, 1));
      }
    }

    for (final entry in pathsByValue.entries) {
      paint.color = _colorTable[entry.key];
      canvas.drawPath(entry.value, paint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(m.height, m.width);
    picture.dispose();

    if (genId != _imageGenId || _disposed) {
      image.dispose();
      return;
    }

    final oldImage = mapImage;
    mapImage = image;
    oldImage?.dispose();
    notifyListeners();
  }

  void _runScanMatcher() {
    if (currentMap == null) return;
    final scanPoints = lidar.points;
    if (scanPoints.length < 10) return;

    final m = currentMap!;
    final odomX = status.odomX;
    final odomY = status.odomY;
    final odomYaw = status.odomYaw;

    final subsampled = <Offset>[];
    for (var i = 0; i < scanPoints.length; i += 3) {
      subsampled.add(scanPoints[i]);
    }
    if (subsampled.length < 5) return;

    final cosOdom = math.cos(odomYaw);
    final sinOdom = math.sin(odomYaw);
    final odomCoords = <double>[];
    for (final p in subsampled) {
      odomCoords.add(odomX + p.dx * cosOdom - p.dy * sinOdom);
      odomCoords.add(odomY + p.dx * sinOdom + p.dy * cosOdom);
    }

    final resInv = 1.0 / m.resolution;
    final baseX = hasCorrection ? correctionX : 0.0;
    final baseY = hasCorrection ? correctionY : 0.0;
    final baseYaw = hasCorrection ? correctionYaw : 0.0;

    double bestScore = -1;
    double bestX = baseX, bestY = baseY, bestYaw = baseYaw;

    for (var yi = -5; yi <= 5; yi++) {
      final dyaw = baseYaw + yi * 0.03;
      final cosC = math.cos(dyaw);
      final sinC = math.sin(dyaw);
      for (var xi = -8; xi <= 8; xi++) {
        final dx = baseX + xi * 0.1;
        for (var yj = -8; yj <= 8; yj++) {
          final dy = baseY + yj * 0.1;
          var score = 0;
          for (var i = 0; i < odomCoords.length; i += 2) {
            final ox = odomCoords[i];
            final oy = odomCoords[i + 1];
            final mx = ox * cosC - oy * sinC + dx;
            final my = ox * sinC + oy * cosC + dy;
            final col = ((mx - m.originX) * resInv).toInt();
            final row = ((my - m.originY) * resInv).toInt();
            if (col >= 0 && col < m.width && row >= 0 && row < m.height) {
              final v = m.grid[row * m.width + col];
              if (v >= 100 && v < 255) score++;
            }
          }
          if (score > bestScore) {
            bestScore = score.toDouble();
            bestX = dx;
            bestY = dy;
            bestYaw = dyaw;
          }
        }
      }
    }

    if (bestScore >= 5) {
      correctionX = bestX;
      correctionY = bestY;
      correctionYaw = bestYaw;
      hasCorrection = true;
    }
  }

  void _onDisconnect() {
    if (_disposed) return;
    status.updateMapStatus(ConnectionStatus.disconnected);
    currentMap = null;
    mapImage?.dispose();
    mapImage = null;
    correctionX = 0.0;
    correctionY = 0.0;
    correctionYaw = 0.0;
    hasCorrection = false;
    notifyListeners();
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    currentMap = null;
    mapImage?.dispose();
    mapImage = null;
    correctionX = 0.0;
    correctionY = 0.0;
    correctionYaw = 0.0;
    hasCorrection = false;
    status.updateMapStatus(ConnectionStatus.disconnected);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _channel?.sink.close();
    mapImage?.dispose();
    super.dispose();
  }
}
