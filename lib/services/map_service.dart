import 'dart:convert';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/robot_status.dart';

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
  MapService(this.status);

  final RobotStatus status;

  WebSocketChannel? _channel;
  bool _disposed = false;
  String _ip = '';
  int _imageGenId = 0;

  OccupancyMap? currentMap;
  ui.Image? mapImage;

  static final _colorTable = List<ui.Color>.generate(256, (v) {
    if (v == 0) return const ui.Color(0x00000000);
    if (v == 255) return const ui.Color(0xFFE8E8E8);
    if (v >= 100) return const ui.Color(0xFF1A1A1A);
    final gray = 230 - (v * 1.8).round();
    return ui.Color.fromARGB(255, gray, gray, gray);
  });

  static final _rgbaTable = _buildRgbaTable();

  static Uint8List _buildRgbaTable() {
    final table = Uint8List(256 * 4);
    for (var v = 0; v < 256; v++) {
      final c = _colorTable[v].toARGB32();
      table[v * 4] = (c >> 16) & 0xff;
      table[v * 4 + 1] = (c >> 8) & 0xff;
      table[v * 4 + 2] = c & 0xff;
      table[v * 4 + 3] = (c >> 24) & 0xff;
    }
    return table;
  }

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
    } catch (_) {}
  }

  void _regenerateImage() {
    if (currentMap == null) return;
    final m = currentMap!;
    final genId = ++_imageGenId;

    final imgH = m.height;
    final imgW = m.width;
    final buffer = Uint8List(imgW * imgH * 4);
    final rgba = _rgbaTable;

    for (var row = 0; row < m.height; row++) {
      final rowBase = row * m.width;
      for (var col = 0; col < m.width; col++) {
        final v = m.grid[rowBase + col];
        final srcOff = v * 4;
        final dstIdx = (col * imgH + row) * 4;
        buffer[dstIdx] = rgba[srcOff];
        buffer[dstIdx + 1] = rgba[srcOff + 1];
        buffer[dstIdx + 2] = rgba[srcOff + 2];
        buffer[dstIdx + 3] = rgba[srcOff + 3];
      }
    }

    final image = ui.decodeImageFromPixelsSync(
      buffer,
      imgH,
      imgW,
      ui.PixelFormat.rgba8888,
    );

    if (genId != _imageGenId || _disposed) {
      image.dispose();
      return;
    }

    final oldImage = mapImage;
    mapImage = image;
    oldImage?.dispose();
    notifyListeners();
  }

  void _onDisconnect() {
    if (_disposed) return;
    status.updateMapStatus(ConnectionStatus.disconnected);
    currentMap = null;
    mapImage?.dispose();
    mapImage = null;
    notifyListeners();
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    currentMap = null;
    mapImage?.dispose();
    mapImage = null;
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
