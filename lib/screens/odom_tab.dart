import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../models/robot_status.dart';
import '../widgets/trajectory_painter.dart';

class OdomTab extends StatefulWidget {
  const OdomTab({super.key});

  @override
  State<OdomTab> createState() => _OdomTabState();
}

class _OdomTabState extends State<OdomTab> {
  double _scale = 40.0;

  @override
  Widget build(BuildContext context) {
    final status = context.watch<RobotStatus>();
    final connected = status.controlStatus == ConnectionStatus.connected;

    if (!connected) {
      return _Placeholder(status: status.controlStatus);
    }

    final yawDeg = status.odomYaw * 180 / math.pi;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _DataCard(
                    title: '位置',
                    icon: CupertinoIcons.location,
                    children: [
                      _DataRow(label: 'X', value: '${status.odomX.toStringAsFixed(3)} m'),
                      _DataRow(label: 'Y', value: '${status.odomY.toStringAsFixed(3)} m'),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DataCard(
                    title: '朝向',
                    icon: CupertinoIcons.compass,
                    children: [
                      _DataRow(
                          label: 'Yaw',
                          value: '${yawDeg.toStringAsFixed(1)}°'),
                      _DataRow(
                          label: '弧度',
                          value: status.odomYaw.toStringAsFixed(3)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _DataCard(
              title: '速度',
              icon: CupertinoIcons.speedometer,
              children: [
                _DataRow(label: 'vx', value: '${status.vx.toStringAsFixed(2)} m/s'),
                _DataRow(label: 'vy', value: '${status.vy.toStringAsFixed(2)} m/s'),
                _DataRow(
                    label: 'vth', value: '${status.vth.toStringAsFixed(2)} rad/s'),
              ],
            ),
            const SizedBox(height: 10),
            _TrajectorySection(
              trajectory: status.trajectory,
              robotX: status.odomX,
              robotY: status.odomY,
              robotYaw: status.odomYaw,
              scale: _scale,
              onZoomIn: () =>
                  setState(() => _scale = (_scale * 1.25).clamp(10.0, 200.0)),
              onZoomOut: () =>
                  setState(() => _scale = (_scale / 1.25).clamp(10.0, 200.0)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.status});
  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      ConnectionStatus.connecting => '连接中…',
      ConnectionStatus.error => '连接失败',
      _ => '未连接',
    };
    return Container(
      color: const Color(0xFFF2F2F7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status == ConnectionStatus.error
                  ? CupertinoIcons.exclamationmark_circle
                  : CupertinoIcons.location,
              size: 36,
              color: status == ConnectionStatus.error
                  ? const Color(0xFFD32F2F)
                  : const Color(0xFFC7C7CC),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.all(Radius.circular(14)),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0x99E8E8EC), width: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: const Color(0xFF8E8E93)),
              const SizedBox(width: 5),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8E8E93),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF3A3A3C),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrajectorySection extends StatelessWidget {
  const _TrajectorySection({
    required this.trajectory,
    required this.robotX,
    required this.robotY,
    required this.robotYaw,
    required this.scale,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final List<Offset> trajectory;
  final double robotX;
  final double robotY;
  final double robotYaw;
  final double scale;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.all(Radius.circular(14)),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0x99E8E8EC), width: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            CustomPaint(
              painter: TrajectoryPainter(
                trajectory: trajectory,
                robotX: robotX,
                robotY: robotY,
                robotYaw: robotYaw,
                scale: scale,
              ),
              child: const SizedBox.expand(),
            ),
            Positioned(
              top: 8,
              left: 12,
              child: Text(
                '轨迹 (${trajectory.length} 点)',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  _ZoomButton(
                    icon: CupertinoIcons.plus,
                    onTap: onZoomIn,
                  ),
                  const SizedBox(width: 4),
                  _ZoomButton(
                    icon: CupertinoIcons.minus,
                    onTap: onZoomOut,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xCCFFFFFF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0x99E8E8EC), width: 0.6),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 14, color: const Color(0xFF2563A8)),
      ),
    );
  }
}
