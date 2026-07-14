import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../models/robot_status.dart';
import '../services/control_service.dart';

class SpeedSliders extends StatelessWidget {
  const SpeedSliders({super.key});

  @override
  Widget build(BuildContext context) {
    final control = context.watch<ControlService>();
    final connected = context.select<RobotStatus, bool>(
      (s) => s.controlStatus == ConnectionStatus.connected,
    );

    return Opacity(
      opacity: connected ? 1.0 : 0.4,
      child: AbsorbPointer(
        absorbing: !connected,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SpeedSlider(
              label: '线速度',
              unit: 'm/s',
              value: control.maxLinear,
              max: 0.5,
              divisions: 50,
              onChanged: (v) => control.setSpeedLimits(linear: v),
            ),
            const SizedBox(height: 6),
            _SpeedSlider(
              label: '角速度',
              unit: 'rad/s',
              value: control.maxAngular,
              max: 1.0,
              divisions: 100,
              onChanged: (v) => control.setSpeedLimits(angular: v),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedSlider extends StatelessWidget {
  const _SpeedSlider({
    required this.label,
    required this.unit,
    required this.value,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String unit;
  final double value;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF3A3A3C),
              ),
            ),
            Text(
              '${value.toStringAsFixed(3)} $unit',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2563A8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        CupertinoSlider(
          value: value,
          min: 0.0,
          max: max,
          divisions: divisions,
          activeColor: const Color(0xFF2563A8),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
