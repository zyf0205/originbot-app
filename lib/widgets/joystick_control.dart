import 'package:flutter/cupertino.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:provider/provider.dart';

import '../models/robot_status.dart';
import '../services/control_service.dart';

class JoystickControl extends StatelessWidget {
  const JoystickControl({super.key});

  @override
  Widget build(BuildContext context) {
    final control = context.read<ControlService>();
    final connected = context.select<RobotStatus, bool>(
      (s) => s.controlStatus == ConnectionStatus.connected,
    );

    return Opacity(
      opacity: connected ? 1.0 : 0.35,
      child: IgnorePointer(
        ignoring: !connected,
        child: Joystick(
          mode: JoystickMode.all,
          period: const Duration(milliseconds: 100),
          includeInitialAnimation: false,
          listener: (StickDragDetails details) {
            control.updateInput(details.x, details.y);
          },
          onStickDragEnd: () => control.releaseInput(),
          base: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE8E8EC),
              border: Border.all(
                color: const Color(0xFFCDCDD2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: const Color(0xFFFFFFFF),
                  blurRadius: 2,
                  offset: const Offset(0, -1),
                  spreadRadius: -1,
                ),
              ],
            ),
          ),
          stick: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment(-0.6, -0.6),
                end: Alignment(0.4, 0.4),
                colors: [
                  Color(0xFF4A90D9),
                  Color(0xFF2563A8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CupertinoColors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
