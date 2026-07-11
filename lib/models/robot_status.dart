import 'package:flutter/foundation.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class RobotStatus extends ChangeNotifier {
  ConnectionStatus controlStatus = ConnectionStatus.disconnected;
  ConnectionStatus videoStatus = ConnectionStatus.disconnected;

  double batteryVoltage = 0.0;
  bool buzzerOn = false;
  bool ledOn = false;

  double vx = 0.0;
  double vy = 0.0;
  double vth = 0.0;

  double roll = 0.0;
  double pitch = 0.0;
  double yaw = 0.0;

  String controlErrorMsg = '';
  String videoErrorMsg = '';

  void updateControlStatus(ConnectionStatus s) {
    if (controlStatus != s) {
      controlStatus = s;
      notifyListeners();
    }
  }

  void updateVideoStatus(ConnectionStatus s) {
    if (videoStatus != s) {
      videoStatus = s;
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

  void updateOdom({double? vx, double? vy, double? vth}) {
    if (vx != null) this.vx = vx;
    if (vy != null) this.vy = vy;
    if (vth != null) this.vth = vth;
    notifyListeners();
  }

  void updateImu({double? roll, double? pitch, double? yaw}) {
    if (roll != null) this.roll = roll;
    if (pitch != null) this.pitch = pitch;
    if (yaw != null) this.yaw = yaw;
    notifyListeners();
  }
}
