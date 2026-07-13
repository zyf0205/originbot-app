import 'dart:math';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class RobotStatus extends ChangeNotifier {
  ConnectionStatus controlStatus = ConnectionStatus.disconnected;
  ConnectionStatus lidarStatus = ConnectionStatus.disconnected;

  double batteryVoltage = 0.0;
  bool buzzerOn = false;
  bool ledOn = false;

  double odomX = 0.0;
  double odomY = 0.0;
  double odomYaw = 0.0;

  double vx = 0.0;
  double vy = 0.0;
  double vth = 0.0;

  final List<Offset> _trajectory = [];
  static const int _maxTrajectoryPoints = 500;
  List<Offset> get trajectory => List.unmodifiable(_trajectory);

  String controlErrorMsg = '';
  String lidarErrorMsg = '';

  void updateControlStatus(ConnectionStatus s) {
    if (controlStatus != s) {
      controlStatus = s;
      notifyListeners();
    }
  }

  void updateLidarStatus(ConnectionStatus s) {
    if (lidarStatus != s) {
      lidarStatus = s;
      notifyListeners();
    }
  }

  void updateStatus({
    double? batteryVoltage,
    bool? buzzerOn,
    bool? ledOn,
  }) {
    if (batteryVoltage != null) this.batteryVoltage = batteryVoltage;
    if (buzzerOn != null) this.buzzerOn = buzzerOn;
    if (ledOn != null) this.ledOn = ledOn;
    notifyListeners();
  }

  void updateOdom({
    double? x,
    double? y,
    double? qx,
    double? qy,
    double? qz,
    double? qw,
    double? vx,
    double? vy,
    double? vth,
  }) {
    if (x != null) odomX = x;
    if (y != null) odomY = y;
    if (qx != null && qy != null && qz != null && qw != null) {
      final siny = 2.0 * (qw * qz + qx * qy);
      final cosy = 1.0 - 2.0 * (qy * qy + qz * qz);
      odomYaw = atan2(siny, cosy);
    }
    if (vx != null) this.vx = vx;
    if (vy != null) this.vy = vy;
    if (vth != null) this.vth = vth;

    final lastPoint = _trajectory.isNotEmpty ? _trajectory.last : null;
    final newPoint = Offset(odomX, odomY);
    if (lastPoint == null || (lastPoint - newPoint).distance > 0.01) {
      _trajectory.add(newPoint);
      if (_trajectory.length > _maxTrajectoryPoints) {
        _trajectory.removeAt(0);
      }
    }

    notifyListeners();
  }

  void resetOdom() {
    odomX = 0.0;
    odomY = 0.0;
    odomYaw = 0.0;
    vx = 0.0;
    vy = 0.0;
    vth = 0.0;
    _trajectory.clear();
    notifyListeners();
  }
}
