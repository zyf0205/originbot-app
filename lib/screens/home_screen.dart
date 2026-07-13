import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../config/ip_history.dart';
import '../models/robot_status.dart';
import '../services/control_service.dart';
import '../services/lidar_service.dart';
import '../widgets/connection_indicator.dart';
import '../widgets/joystick_control.dart';
import '../widgets/point_cloud_painter.dart';
import '../widgets/speed_sliders.dart';
import '../widgets/status_panel.dart';
import '../widgets/trajectory_painter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _ipCtrl;
  String? _error;
  int _viewMode = 0;
  double _lidarScale = 50.0;
  double _trajScale = 40.0;

  @override
  void initState() {
    super.initState();
    _ipCtrl = TextEditingController(text: context.read<ControlService>().ip);
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    super.dispose();
  }

  void _connect() {
    final ip = _ipCtrl.text.trim();
    final control = context.read<ControlService>();
    final err = control.validateIp(ip);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() => _error = null);
    final lidar = context.read<LidarService>();
    control.setIp(ip);
    lidar.setIp(ip);
    IpHistory.add(ip);
    control.connect();
    lidar.connect();
  }

  void _disconnect() {
    context.read<ControlService>().disconnect();
    context.read<LidarService>().disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<RobotStatus>();
    final isConnected = status.controlStatus == ConnectionStatus.connected ||
        status.lidarStatus == ConnectionStatus.connected;
    final connecting = status.controlStatus == ConnectionStatus.connecting ||
        status.lidarStatus == ConnectionStatus.connecting;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('OriginBot'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ConnectionIndicator(),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: connecting
                  ? null
                  : (isConnected ? _disconnect : _connect),
              child: Icon(
                CupertinoIcons.power,
                size: 22,
                color: isConnected
                    ? CupertinoColors.activeGreen
                    : CupertinoColors.systemGrey3,
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (!isConnected) _buildConnectionCard(connecting),
            _buildSegmentedControl(),
            Expanded(child: _buildCanvasArea()),
            _buildControlArea(),
            const StatusPanel(),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard(bool connecting) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.all(Radius.circular(14)),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0x99E8E8EC), width: 0.6),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.wifi,
                size: 16,
                color: const Color(0xFF8E8E93),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: CupertinoTextField(
                  controller: _ipCtrl,
                  placeholder: '机器人 IP 地址',
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enabled: !connecting,
                  prefix: const SizedBox(width: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(8),
                    border: _error != null
                        ? Border.all(
                            color: CupertinoColors.systemRed,
                            width: 1,
                          )
                        : null,
                  ),
                  style: const TextStyle(fontSize: 14),
                  placeholderStyle: const TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 14,
                  ),
                  onChanged: (text) {
                    context.read<ControlService>().setIp(text);
                    if (_error != null) setState(() => _error = null);
                  },
                ),
              ),
            ],
          ),
          if (_error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, left: 22),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: CupertinoColors.systemRed,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSegmentedControl(
          groupValue: _viewMode,
          onValueChanged: (int value) => setState(() => _viewMode = value),
          children: {
            0: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Text('雷达点云'),
            ),
            1: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Text('里程轨迹'),
            ),
          },
        ),
      ),
    );
  }

  Widget _buildCanvasArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.all(Radius.circular(14)),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0x99E8E8EC), width: 0.6),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            _buildCanvas(),
            Positioned(
              top: 8,
              right: 8,
              child: _buildZoomControls(),
            ),
            if (_viewMode == 0) _buildLidarInfoBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    if (_viewMode == 0) {
      return _buildLidarCanvas();
    }
    return _buildTrajectoryCanvas();
  }

  Widget _buildLidarCanvas() {
    final status = context.select<RobotStatus, ConnectionStatus>(
      (s) => s.lidarStatus,
    );
    if (status != ConnectionStatus.connected) {
      return _CanvasPlaceholder(status: status, isLidar: true);
    }
    final lidar = context.watch<LidarService>();
    return GestureDetector(
      onScaleUpdate: (details) {
        final newScale = (_lidarScale * details.scale).clamp(15.0, 300.0);
        if ((newScale - _lidarScale).abs() > 0.5) {
          setState(() => _lidarScale = newScale);
        }
      },
      child: ColoredBox(
        color: const Color(0xFFF8F8FA),
        child: RepaintBoundary(
          child: CustomPaint(
            painter: PointCloudPainter(
              points: lidar.points,
              scale: _lidarScale,
              rangeMin: lidar.rangeMin,
              rangeMax: lidar.rangeMax,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  Widget _buildTrajectoryCanvas() {
    final status = context.select<RobotStatus, ConnectionStatus>(
      (s) => s.controlStatus,
    );
    if (status != ConnectionStatus.connected) {
      return _CanvasPlaceholder(status: status, isLidar: false);
    }
    final robotStatus = context.watch<RobotStatus>();
    return GestureDetector(
      onScaleUpdate: (details) {
        final newScale = (_trajScale * details.scale).clamp(10.0, 200.0);
        if ((newScale - _trajScale).abs() > 0.5) {
          setState(() => _trajScale = newScale);
        }
      },
      child: CustomPaint(
        painter: TrajectoryPainter(
          trajectory: robotStatus.trajectory,
          robotX: robotStatus.odomX,
          robotY: robotStatus.odomY,
          robotYaw: robotStatus.odomYaw,
          scale: _trajScale,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildZoomControls() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x99E8E8EC), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() {
              if (_viewMode == 0) {
                _lidarScale = (_lidarScale * 1.25).clamp(15.0, 300.0);
              } else {
                _trajScale = (_trajScale * 1.25).clamp(10.0, 200.0);
              }
            }),
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
            width: 1,
            height: 24,
            color: const Color(0xFFE8E8EC),
          ),
          GestureDetector(
            onTap: () => setState(() {
              if (_viewMode == 0) {
                _lidarScale = (_lidarScale / 1.25).clamp(15.0, 300.0);
              } else {
                _trajScale = (_trajScale / 1.25).clamp(10.0, 200.0);
              }
            }),
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

  Widget _buildLidarInfoBar() {
    final lidar = context.watch<LidarService>();
    return Positioned(
      bottom: 8,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xCCFFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x99E8E8EC), width: 0.6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _infoItem('点数', '${lidar.points.length}'),
            _infoItem(
              '量程',
              '${lidar.rangeMin.toStringAsFixed(1)}-${lidar.rangeMax.toStringAsFixed(1)}m',
            ),
            _infoItem('缩放', '${_lidarScale.toStringAsFixed(0)}px/m'),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value) {
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

  Widget _buildControlArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.all(Radius.circular(14)),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0x99E8E8EC), width: 0.6),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 5, child: JoystickControl()),
          SizedBox(width: 10),
          Expanded(flex: 4, child: SpeedSliders()),
        ],
      ),
    );
  }
}

class _CanvasPlaceholder extends StatelessWidget {
  const _CanvasPlaceholder({required this.status, required this.isLidar});
  final ConnectionStatus status;
  final bool isLidar;

  @override
  Widget build(BuildContext context) {
    final text = isLidar
        ? switch (status) {
            ConnectionStatus.connecting => '雷达连接中…',
            ConnectionStatus.error => '雷达连接失败',
            _ => '雷达未连接',
          }
        : switch (status) {
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
                  : isLidar
                      ? CupertinoIcons.antenna_radiowaves_left_right
                      : CupertinoIcons.location,
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
          ],
        ),
      ),
    );
  }
}
