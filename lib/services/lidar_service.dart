import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/robot_status.dart';

class LidarService extends ChangeNotifier {
  LidarService(this.status);

  final RobotStatus status;

  WebSocketChannel? _channel;
  bool _disposed = false;
  String _ip = '';

  List<Offset> points = [];
  double rangeMin = 0.0;
  double rangeMax = 0.0;

  void setIp(String ip) {
    _ip = ip.trim();
  }

  Future<void> connect() async {
    if (_ip.isEmpty) return;
    if (status.lidarStatus == ConnectionStatus.connecting) return;
    _channel?.sink.close();
    _channel = null;
    status.updateLidarStatus(ConnectionStatus.connecting);
    try {
      final uri = Uri.parse('ws://$_ip:9090/scan');
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('雷达连接超时(5s)，请检查 /scan 端点'),
      );
      status.updateLidarStatus(ConnectionStatus.connected);
      _channel!.stream.listen(
        _onMessage,
        onError: (_) => _onDisconnect(),
        onDone: _onDisconnect,
      );
    } catch (e) {
      status.lidarErrorMsg = e.toString();
      status.updateLidarStatus(ConnectionStatus.error);
    }
  }

  void _onMessage(dynamic data) {
    if (data is! List<int>) return;
    _parseScanData(Uint8List.fromList(data));
    notifyListeners();
  }

  void _parseScanData(Uint8List bytes) {
    if (bytes.length < 12) return;
    final byteData = ByteData.sublistView(bytes);
    final pointCount = byteData.getUint32(0, Endian.little);
    rangeMin = byteData.getFloat32(4, Endian.little);
    rangeMax = byteData.getFloat32(8, Endian.little);

    final expectedLen = 12 + pointCount * 8;
    if (bytes.length < expectedLen) return;

    final result = <Offset>[];
    for (var i = 0; i < pointCount; i++) {
      final offset = 12 + i * 8;
      final x = byteData.getFloat32(offset, Endian.little);
      final y = byteData.getFloat32(offset + 4, Endian.little);
      result.add(Offset(x, y));
    }
    points = result;
  }

  void _onDisconnect() {
    if (_disposed) return;
    status.updateLidarStatus(ConnectionStatus.disconnected);
    points = [];
    notifyListeners();
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    points = [];
    status.updateLidarStatus(ConnectionStatus.disconnected);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _channel?.sink.close();
    super.dispose();
  }
}
