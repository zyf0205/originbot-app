import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/robot_status.dart';
import '../config/ip_history.dart';

class ControlService extends ChangeNotifier {
  ControlService(this.status);

  final RobotStatus status;

  WebSocketChannel? _channel;
  Timer? _publishTimer;
  bool _disposed = false;
  String _ip = IpHistory.lastIp;

  double _inputX = 0.0;
  double _inputY = 0.0;
  double maxLinear = 0.3;
  double maxAngular = 0.5;

  String get ip => _ip;

  void setIp(String ip) {
    _ip = ip.trim();
  }

  bool _isValidIp(String ip) {
    if (ip.trim().isEmpty) return false;
    final parts = ip.split('.');
    if (parts.length == 4) {
      return parts.every((p) {
        final n = int.tryParse(p);
        return n != null && n >= 0 && n <= 255;
      });
    }
    return ip.trim().isNotEmpty;
  }

  String? validateIp(String ip) {
    if (ip.trim().isEmpty) return '请输入 IP 地址';
    if (!_isValidIp(ip.trim())) return 'IP 格式无效';
    return null;
  }

  Future<void> connect() async {
    final ip = _ip;
    if (ip.isEmpty) return;
    final err = validateIp(ip);
    if (err != null) {
      status.controlErrorMsg = err;
      status.updateControlStatus(ConnectionStatus.error);
      return;
    }
    if (status.controlStatus == ConnectionStatus.connecting) return;
    _channel?.sink.close();
    _channel = null;
    status.updateControlStatus(ConnectionStatus.connecting);
    try {
      final uri = Uri.parse('ws://$ip:9090/control');
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('控制连接超时(5s)'),
      );
      status.updateControlStatus(ConnectionStatus.connected);
      _startPublishing();
      _channel!.stream.listen(
        _onMessage,
        onError: (_) => _onDisconnect(),
        onDone: _onDisconnect,
      );
    } catch (e) {
      status.controlErrorMsg = e.toString();
      status.updateControlStatus(ConnectionStatus.error);
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String?;
      if (type == null) return;
      switch (type) {
        case 'connected':
          break;
        case 'status':
          status.updateStatus(
            batteryVoltage: (data['battery_voltage'] as num?)?.toDouble(),
            buzzerOn: data['buzzer_on'] as bool?,
            ledOn: data['led_on'] as bool?,
          );
        case 'odom':
          status.updateOdom(
            vx: (data['vx'] as num?)?.toDouble(),
            vy: (data['vy'] as num?)?.toDouble(),
            vth: (data['vth'] as num?)?.toDouble(),
          );
        case 'error':
          status.controlErrorMsg = data['msg']?.toString() ?? '未知错误';
      }
    } catch (_) {}
  }

  void _startPublishing() {
    _publishTimer?.cancel();
    _publishTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _publishTick(),
    );
  }

  void _publishTick() {
    if (status.controlStatus != ConnectionStatus.connected) return;
    final linearX = -_inputY * maxLinear;
    final angularZ = -_inputX * maxAngular;
    _channel?.sink.add(jsonEncode({
      'type': 'cmd_vel',
      'linear_x': linearX,
      'linear_y': 0.0,
      'angular_z': angularZ,
    }));
  }

  void updateInput(double horizontal, double vertical) {
    _inputX = horizontal.clamp(-1.0, 1.0);
    _inputY = vertical.clamp(-1.0, 1.0);
  }

  void releaseInput() {
    _inputX = 0.0;
    _inputY = 0.0;
  }

  void sendStop() {
    _inputX = 0.0;
    _inputY = 0.0;
    if (status.controlStatus == ConnectionStatus.connected) {
      _channel?.sink.add(jsonEncode({'type': 'stop'}));
    }
  }

  void sendBuzzer(bool on) {
    if (status.controlStatus != ConnectionStatus.connected) return;
    _channel?.sink.add(jsonEncode({'type': 'buzzer', 'on': on}));
    status.updateStatus(buzzerOn: on);
  }

  void sendLed(bool on) {
    if (status.controlStatus != ConnectionStatus.connected) return;
    _channel?.sink.add(jsonEncode({'type': 'led', 'on': on}));
    status.updateStatus(ledOn: on);
  }

  void setSpeedLimits({double? linear, double? angular}) {
    if (linear != null) maxLinear = linear.clamp(0.0, 0.5);
    if (angular != null) maxAngular = angular.clamp(0.0, 1.0);
    notifyListeners();
  }

  void _onDisconnect() {
    if (_disposed) return;
    _publishTimer?.cancel();
    _publishTimer = null;
    _inputX = 0.0;
    _inputY = 0.0;
    status.updateControlStatus(ConnectionStatus.disconnected);
  }

  void disconnect() {
    _publishTimer?.cancel();
    _publishTimer = null;
    _channel?.sink.close();
    _channel = null;
    _inputX = 0.0;
    _inputY = 0.0;
    status.updateControlStatus(ConnectionStatus.disconnected);
  }

  @override
  void dispose() {
    _disposed = true;
    _publishTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
