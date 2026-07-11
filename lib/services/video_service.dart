import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/robot_status.dart';

class VideoService extends ChangeNotifier {
  VideoService(this.status);

  final RobotStatus status;

  WebSocketChannel? _channel;
  bool _disposed = false;
  String _ip = '';

  Uint8List? latestFrame;

  void setIp(String ip) {
    _ip = ip.trim();
  }

  Future<void> connect() async {
    if (_ip.isEmpty) return;
    if (status.videoStatus == ConnectionStatus.connecting) return;
    _channel?.sink.close();
    _channel = null;
    status.updateVideoStatus(ConnectionStatus.connecting);
    try {
      final uri = Uri.parse('ws://$_ip:9090/video');
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('视频连接超时(5s)，请检查 /video 端点'),
      );
      status.updateVideoStatus(ConnectionStatus.connected);
      _channel!.stream.listen(
        _onMessage,
        onError: (_) => _onDisconnect(),
        onDone: _onDisconnect,
      );
    } catch (e) {
      status.videoErrorMsg = e.toString();
      status.updateVideoStatus(ConnectionStatus.error);
    }
  }

  void _onMessage(dynamic data) {
    if (data is! List<int>) return;
    latestFrame = Uint8List.fromList(data);
    notifyListeners();
  }

  void _onDisconnect() {
    if (_disposed) return;
    status.updateVideoStatus(ConnectionStatus.disconnected);
    latestFrame = null;
    notifyListeners();
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    latestFrame = null;
    status.updateVideoStatus(ConnectionStatus.disconnected);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _channel?.sink.close();
    super.dispose();
  }
}
