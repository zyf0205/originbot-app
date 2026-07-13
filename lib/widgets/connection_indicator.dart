import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../models/robot_status.dart';

class ConnectionIndicator extends StatelessWidget {
  const ConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.select<RobotStatus, ConnectionStatus>(
      (s) => s.controlStatus,
    );
    final ls = context.select<RobotStatus, ConnectionStatus>(
      (s) => s.lidarStatus,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dot(color: _color(cs)),
        const SizedBox(width: 5),
        _Dot(color: _color(ls)),
      ],
    );
  }

  Color _color(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.connected:
        return const Color(0xFF34C759);
      case ConnectionStatus.connecting:
        return const Color(0xFFE8A000);
      case ConnectionStatus.error:
        return const Color(0xFFD32F2F);
      case ConnectionStatus.disconnected:
        return const Color(0xFFD1D1D6);
    }
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 3,
            spreadRadius: 0.5,
          ),
        ],
      ),
    );
  }
}
