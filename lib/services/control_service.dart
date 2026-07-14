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
  bool _userDisconnected = false;
  int _watchdogCounter = 0;
  static const int _watchdogThreshold = 60;
  int _zeroInputMovingCounter = 0;
  int _unresponsiveRetryCount = 0;
  static const int _unresponsiveThreshold = 60; // 3s at 50ms
  static const int _maxUnresponsiveRetries = 2;
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

  Future<void> connect({bool manual = true}) async {
    if (manual) _unresponsiveRetryCount = 0;
    _userDisconnected = false;
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
    _watchdogCounter = 0;
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
            x: (data['x'] as num?)?.toDouble(),
            y: (data['y'] as num?)?.toDouble(),
            qx: (data['qx'] as num?)?.toDouble(),
            qy: (data['qy'] as num?)?.toDouble(),
            qz: (data['qz'] as num?)?.toDouble(),
            qw: (data['qw'] as num?)?.toDouble(),
            vx: (data['vx'] as num?)?.toDouble(),
            vy: (data['vy'] as num?)?.toDouble(),
            vth: (data['vth'] as num?)?.toDouble(),
            mapX: (data['map_x'] as num?)?.toDouble(),
            mapY: (data['map_y'] as num?)?.toDouble(),
            mapYaw: (data['map_yaw'] as num?)?.toDouble(),
          );
        case 'error':
          status.controlErrorMsg = data['msg']?.toString() ?? '未知错误';
      }
    } catch (_) {}
  }

  void _startPublishing() {
    _publishTimer?.cancel();
    _watchdogCounter = 0;
    _zeroInputMovingCounter = 0;
    try {
      _channel?.sink.add(jsonEncode({'type': 'stop'}));
    } catch (_) {}
    _publishTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _publishTick(),
    );
  }

  void _publishTick() {
    if (status.controlStatus != ConnectionStatus.connected) return;

    _watchdogCounter++;
    if (_watchdogCounter > _watchdogThreshold) {
      _handleDeadConnection();
      return;
    }

    final linearX = -_inputY * maxLinear;
    final angularZ = -_inputX * maxAngular;
    try {
      _channel?.sink.add(jsonEncode({
        'type': 'cmd_vel',
        'linear_x': linearX,
        'linear_y': 0.0,
        'angular_z': angularZ,
      }));
    } catch (_) {
      _handleDeadConnection();
      return;
    }

    // Detect unresponsive control channel: user released the joystick
    // (zero input) but the robot is still moving. The bridge is likely
    // still sending odom but not processing incoming cmd_vel commands.
    if (_inputX == 0.0 && _inputY == 0.0 &&
        (status.vx.abs() > 0.05 || status.vth.abs() > 0.05)) {
      _zeroInputMovingCounter++;
      if (_zeroInputMovingCounter >= _unresponsiveThreshold) {
        _zeroInputMovingCounter = 0;
        if (_unresponsiveRetryCount < _maxUnresponsiveRetries) {
          _unresponsiveRetryCount++;
          status.controlErrorMsg = '控制无响应，正在重连…';
          _handleDeadConnection();
        } else {
          _publishTimer?.cancel();
          _publishTimer = null;
          _inputX = 0.0;
          _inputY = 0.0;
          try {
            _channel?.sink.add(jsonEncode({'type': 'stop'}));
          } catch (_) {}
          _channel?.sink.close();
          _channel = null;
          status.controlErrorMsg = '控制持续无响应，请重启机器人桥接节点';
          status.updateControlStatus(ConnectionStatus.error);
        }
        return;
      }
    } else {
      _zeroInputMovingCounter = 0;
      if (_inputX == 0.0 && _inputY == 0.0 &&
          status.vx.abs() <= 0.05 && status.vth.abs() <= 0.05) {
        _unresponsiveRetryCount = 0;
      }
    }
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
      try {
        _channel?.sink.add(jsonEncode({'type': 'stop'}));
      } catch (_) {}
    }
  }

  void sendBuzzer(bool on) {
    if (status.controlStatus != ConnectionStatus.connected) return;
    try {
      _channel?.sink.add(jsonEncode({'type': 'buzzer', 'on': on}));
    } catch (_) {
      return;
    }
    status.updateStatus(buzzerOn: on);
  }

  void sendLed(bool on) {
    if (status.controlStatus != ConnectionStatus.connected) return;
    try {
      _channel?.sink.add(jsonEncode({'type': 'led', 'on': on}));
    } catch (_) {
      return;
    }
    status.updateStatus(ledOn: on);
  }

  void setSpeedLimits({double? linear, double? angular}) {
    if (linear != null) maxLinear = linear.clamp(0.0, 0.5);
    if (angular != null) maxAngular = angular.clamp(0.0, 1.0);
    notifyListeners();
  }

  void _handleDeadConnection() {
    if (_disposed) return;
    _publishTimer?.cancel();
    _publishTimer = null;
    _inputX = 0.0;
    _inputY = 0.0;
    try {
      _channel?.sink.add(jsonEncode({'type': 'stop'}));
    } catch (_) {}
    _channel?.sink.close();
    _channel = null;
    status.resetOdom();
    status.updateControlStatus(ConnectionStatus.disconnected);
    if (!_userDisconnected && !_disposed) {
      connect(manual: false);
    }
  }

  void _onDisconnect() {
    if (_disposed) return;
    _publishTimer?.cancel();
    _publishTimer = null;
    _inputX = 0.0;
    _inputY = 0.0;
    status.resetOdom();
    status.updateControlStatus(ConnectionStatus.disconnected);
    if (!_userDisconnected && !_disposed) {
      connect(manual: false);
    }
  }

  void disconnect() {
    _userDisconnected = true;
    _zeroInputMovingCounter = 0;
    _unresponsiveRetryCount = 0;
    _publishTimer?.cancel();
    _publishTimer = null;
    _channel?.sink.close();
    _channel = null;
    _inputX = 0.0;
    _inputY = 0.0;
    status.resetOdom();
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
