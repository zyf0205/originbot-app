import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../models/robot_status.dart';
import '../services/control_service.dart';

class StatusPanel extends StatelessWidget {
  const StatusPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<RobotStatus>();
    final connected = status.controlStatus == ConnectionStatus.connected;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BatteryRow(voltage: status.batteryVoltage),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _InfoChip(
                  icon: CupertinoIcons.speedometer,
                  text: !connected
                      ? '--'
                      : '${status.vx.toStringAsFixed(2)} m/s  ${status.vth.toStringAsFixed(2)} r/s',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoChip(
                  icon: CupertinoIcons.location,
                  text: !connected
                      ? '--'
                      : 'R${status.roll.toStringAsFixed(1)}° P${status.pitch.toStringAsFixed(1)}° Y${status.yaw.toStringAsFixed(1)}°',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ToggleChip(
                label: '蜂鸣器',
                active: status.buzzerOn,
                enabled: connected,
                onTap: () =>
                    context.read<ControlService>().sendBuzzer(!status.buzzerOn),
              ),
              const SizedBox(width: 8),
              _ToggleChip(
                label: 'LED',
                active: status.ledOn,
                enabled: connected,
                onTap: () =>
                    context.read<ControlService>().sendLed(!status.ledOn),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BatteryRow extends StatelessWidget {
  const _BatteryRow({required this.voltage});
  final double voltage;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (voltage <= 0) {
      color = const Color(0xFF8E8E93);
      label = '-- V';
    } else if (voltage < 10.5) {
      color = const Color(0xFFD32F2F);
      label = '${voltage.toStringAsFixed(1)}V 需充电';
    } else if (voltage < 11.5) {
      color = const Color(0xFFE8A000);
      label = '${voltage.toStringAsFixed(1)}V';
    } else {
      color = const Color(0xFF34C759);
      label = '${voltage.toStringAsFixed(1)}V';
    }
    return Row(
      children: [
        Icon(CupertinoIcons.battery_75_percent, color: color, size: 18),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: const Color(0xFF8E8E93)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF3A3A3C),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: !enabled
              ? const Color(0xFFF2F2F7)
              : active
                  ? const Color(0xFF2563A8).withValues(alpha: 0.1)
                  : const Color(0xFFE8E8EC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '$label ${active ? '开' : '关'}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: !enabled
                ? const Color(0xFFAEAEB2)
                : active
                    ? const Color(0xFF2563A8)
                    : const Color(0xFF8E8E93),
          ),
        ),
      ),
    );
  }
}
