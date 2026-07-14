import 'dart:math';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class RobotStatus extends ChangeNotifier {
  ConnectionStatus controlStatus = ConnectionStatus.disconnected;
  ConnectionStatus lidarStatus = ConnectionStatus.disconnected;
  ConnectionStatus mapStatus = ConnectionStatus.disconnected;

  double batteryVoltage = 0.0;
  bool buzzerOn = false;
  bool ledOn = false;

  double odomX = 0.0;
  double odomY = 0.0;
  double odomYaw = 0.0;

  double mapX = 0.0;
  double mapY = 0.0;
  double mapYaw = 0.0;
  bool hasMapPose = false;

  double get displayX => hasMapPose ? mapX : odomX;
  double get displayY => hasMapPose ? mapY : odomY;
  double get displayYaw => hasMapPose ? mapYaw : odomYaw;

  double vx = 0.0;
  double vy = 0.0;
  double vth = 0.0;

  final List<Offset> _trajectory = [];
  List<Offset> _trajectoryView = const [];
  static const int _maxTrajectoryPoints = 500;
  List<Offset> get trajectory => _trajectoryView;

  String controlErrorMsg = '';
  String lidarErrorMsg = '';
  String mapErrorMsg = '';

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

  void updateMapStatus(ConnectionStatus s) {
    if (mapStatus != s) {
      mapStatus = s;
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
    double? mapX,
    double? mapY,
    double? mapYaw,
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

    if (mapX != null) this.mapX = mapX;
    if (mapY != null) this.mapY = mapY;
    if (mapYaw != null) {
      this.mapYaw = mapYaw;
      hasMapPose = true;
    }

    final poseX = hasMapPose ? this.mapX : odomX;
    final poseY = hasMapPose ? this.mapY : odomY;
    final lastPoint = _trajectory.isNotEmpty ? _trajectory.last : null;
    final newPoint = Offset(poseX, poseY);
    if (lastPoint == null || (lastPoint - newPoint).distance > 0.01) {
      _trajectory.add(newPoint);
      if (_trajectory.length > _maxTrajectoryPoints) {
        _trajectory.removeAt(0);
      }
      _trajectoryView = List.unmodifiable(_trajectory);
    }

    notifyListeners();
  }

  void resetOdom() {
    odomX = 0.0;
    odomY = 0.0;
    odomYaw = 0.0;
    mapX = 0.0;
    mapY = 0.0;
    mapYaw = 0.0;
    hasMapPose = false;
    vx = 0.0;
    vy = 0.0;
    vth = 0.0;
    _trajectory.clear();
    _trajectoryView = const [];
    notifyListeners();
  }
}
