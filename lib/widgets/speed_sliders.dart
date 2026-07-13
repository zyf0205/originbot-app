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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CompactSlider(
              label: '线速度',
              value: control.maxLinear,
              max: 0.5,
              suffix: control.maxLinear.toStringAsFixed(2),
              onChanged: (v) => control.setSpeedLimits(linear: v),
            ),
            const SizedBox(height: 6),
            _CompactSlider(
              label: '角速度',
              value: control.maxAngular,
              max: 1.0,
              suffix: control.maxAngular.toStringAsFixed(2),
              onChanged: (v) => control.setSpeedLimits(angular: v),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactSlider extends StatelessWidget {
  const _CompactSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8E8E93),
              ),
            ),
            Text(
              suffix,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF2563A8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        CupertinoSlider(
          value: value,
          min: 0.0,
          max: max,
          activeColor: const Color(0xFF2563A8),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
