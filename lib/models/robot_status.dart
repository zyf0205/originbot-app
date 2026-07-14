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

  // map→odom correction: a slowly-varying 2D rigid transform computed when a
  // map pose arrives, then applied to real-time odom for latency-free display.
  double _corrX = 0.0;
  double _corrY = 0.0;
  double _corrYaw = 0.0;
  bool _hasCorrection = false;

  double get displayX => _hasCorrection
      ? odomX * cos(_corrYaw) - odomY * sin(_corrYaw) + _corrX
      : odomX;
  double get displayY => _hasCorrection
      ? odomX * sin(_corrYaw) + odomY * cos(_corrYaw) + _corrY
      : odomY;
  double get displayYaw => _hasCorrection ? odomYaw + _corrYaw : odomYaw;

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

    // Recompute map→odom correction whenever a map pose is available.
    // The correction drifts slowly, so even if the map pose is slightly stale
    // (TF latency), applying it to real-time odom eliminates display lag.
    if (hasMapPose) {
      _corrYaw = _normalizeAngle(this.mapYaw - odomYaw);
      final cosC = cos(_corrYaw);
      final sinC = sin(_corrYaw);
      _corrX = this.mapX - (odomX * cosC - odomY * sinC);
      _corrY = this.mapY - (odomX * sinC + odomY * cosC);
      _hasCorrection = true;
    }

    final poseX = displayX;
    final poseY = displayY;
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
    _corrX = 0.0;
    _corrY = 0.0;
    _corrYaw = 0.0;
    _hasCorrection = false;
    vx = 0.0;
    vy = 0.0;
    vth = 0.0;
    _trajectory.clear();
    _trajectoryView = const [];
    notifyListeners();
  }

  static double _normalizeAngle(double a) {
    while (a > pi) {
      a -= 2 * pi;
    }
    while (a < -pi) {
      a += 2 * pi;
    }
    return a;
  }
}
