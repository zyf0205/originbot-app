import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../models/robot_status.dart';
import '../services/lidar_service.dart';
import '../widgets/point_cloud_painter.dart';

class LidarMapTab extends StatefulWidget {
  const LidarMapTab({super.key});

  @override
  State<LidarMapTab> createState() => _LidarMapTabState();
}

class _LidarMapTabState extends State<LidarMapTab> {
  double _scale = 50.0; // 1 米 = 50 像素

  void _zoomIn() {
    setState(() => _scale = (_scale * 1.25).clamp(15.0, 300.0));
  }

  void _zoomOut() {
    setState(() => _scale = (_scale / 1.25).clamp(15.0, 300.0));
  }

  @override
  Widget build(BuildContext context) {
    final lidarStatus = context.select<RobotStatus, ConnectionStatus>(
      (s) => s.lidarStatus,
    );

    if (lidarStatus != ConnectionStatus.connected) {
      return _Placeholder(status: lidarStatus);
    }

    return Stack(
      children: [
        GestureDetector(
          onScaleUpdate: (details) {
            final newScale = (_scale * details.scale).clamp(15.0, 300.0);
            if ((newScale - _scale).abs() > 0.5) {
              setState(() => _scale = newScale);
            }
          },
          child: ColoredBox(
            color: const Color(0xFFF8F8FA),
            child: _PointCloudView(scale: _scale),
          ),
        ),
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: _LidarInfoBar(scale: _scale),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: _ZoomControls(
            onZoomIn: _zoomIn,
            onZoomOut: _zoomOut,
          ),
        ),
      ],
    );
  }
}

class _PointCloudView extends StatelessWidget {
  const _PointCloudView({required this.scale});
  final double scale;

  @override
  Widget build(BuildContext context) {
    final lidar = context.watch<LidarService>();
    return RepaintBoundary(
      child: CustomPaint(
        painter: PointCloudPainter(
          points: lidar.points,
          scale: scale,
          rangeMin: lidar.rangeMin,
          rangeMax: lidar.rangeMax,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LidarInfoBar extends StatelessWidget {
  const _LidarInfoBar({required this.scale});
  final double scale;

  @override
  Widget build(BuildContext context) {
    final lidar = context.watch<LidarService>();
    return _InfoBar(
      pointCount: lidar.points.length,
      rangeMin: lidar.rangeMin,
      rangeMax: lidar.rangeMax,
      scale: scale,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.status});
  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final errorMsg =
        context.select<RobotStatus, String?>((s) => s.lidarErrorMsg);
    final lidar = context.read<LidarService>();
    final text = switch (status) {
      ConnectionStatus.connecting => '雷达连接中…',
      ConnectionStatus.connected => '等待扫描数据…',
      ConnectionStatus.error => '雷达连接失败',
      _ => '雷达未连接',
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
                  : CupertinoIcons.antenna_radiowaves_left_right,
              size: 36,
              color: status == ConnectionStatus.error
                  ? const Color(0xFFD32F2F)
                  : const Color(0xFFC7C7CC),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 13,
              ),
            ),
            if (status == ConnectionStatus.error && errorMsg != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  errorMsg,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD32F2F),
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => lidar.connect(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563A8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '重试',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoBar extends StatelessWidget {
  const _InfoBar({
    required this.pointCount,
    required this.rangeMin,
    required this.rangeMax,
    required this.scale,
  });

  final int pointCount;
  final double rangeMin;
  final double rangeMax;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x99E8E8EC), width: 0.6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _InfoItem(label: '点数', value: '$pointCount'),
          _InfoItem(
              label: '量程',
              value: '${rangeMin.toStringAsFixed(1)}-${rangeMax.toStringAsFixed(1)}m'),
          _InfoItem(label: '缩放', value: '${scale.toStringAsFixed(0)}px/m'),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF8E8E93),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3A3A3C),
          ),
        ),
      ],
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.onZoomIn, required this.onZoomOut});
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x99E8E8EC), width: 0.6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onZoomIn,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.plus,
                size: 18,
                color: Color(0xFF2563A8),
              ),
            ),
          ),
          Container(
            width: 24,
            height: 0.5,
            color: const Color(0xFFE8E8EC),
          ),
          GestureDetector(
            onTap: onZoomOut,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.minus,
                size: 18,
                color: Color(0xFF2563A8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
