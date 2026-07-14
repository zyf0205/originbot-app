import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../config/ip_history.dart';
import '../models/robot_status.dart';
import '../services/control_service.dart';
import '../services/lidar_service.dart';
import '../services/map_service.dart';
import '../widgets/connection_indicator.dart';
import '../widgets/joystick_control.dart';
import '../widgets/map_painter.dart';
import '../widgets/speed_sliders.dart';
import '../widgets/status_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _ipCtrl;
  String? _error;

  double _scale = 40.0;
  Offset _pan = Offset.zero;
  double _initialScale = 40.0;
  bool _followRobot = true;

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
    final mapService = context.read<MapService>();
    control.setIp(ip);
    lidar.setIp(ip);
    mapService.setIp(ip);
    IpHistory.add(ip);
    control.connect();
    lidar.connect();
    mapService.connect();
  }

  void _disconnect() {
    context.read<ControlService>().disconnect();
    context.read<LidarService>().disconnect();
    context.read<MapService>().disconnect();
  }

  void _resetView() {
    setState(() {
      _followRobot = true;
      _pan = Offset.zero;
      _scale = 40.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controlStatus = context.select<RobotStatus, ConnectionStatus>(
        (s) => s.controlStatus);
    final lidarStatus = context.select<RobotStatus, ConnectionStatus>(
        (s) => s.lidarStatus);
    final mapStatus = context.select<RobotStatus, ConnectionStatus>(
        (s) => s.mapStatus);
    final isConnected = controlStatus == ConnectionStatus.connected ||
        lidarStatus == ConnectionStatus.connected ||
        mapStatus == ConnectionStatus.connected;
    final connecting = controlStatus == ConnectionStatus.connecting ||
        lidarStatus == ConnectionStatus.connecting ||
        mapStatus == ConnectionStatus.connecting;

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
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x99E8E8EC), width: 0.6),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A000000),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
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
                    borderRadius: BorderRadius.circular(10),
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

  Widget _buildCanvasArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x99E8E8EC), width: 0.6),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A000000),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            _buildCanvas(),
            Positioned(
              top: 8,
              right: 8,
              child: _buildZoomControls(),
            ),
            _buildInfoBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    final hasMap = context.select<RobotStatus, bool>(
      (s) => s.mapStatus == ConnectionStatus.connected,
    );
    final hasControl = context.select<RobotStatus, bool>(
      (s) => s.controlStatus == ConnectionStatus.connected,
    );

    if (!hasMap && !hasControl) {
      final status = context.read<RobotStatus>();
      return _CanvasPlaceholder(status: status.mapStatus, label: '地图');
    }

    final mapService = context.watch<MapService>();
    final lidar = context.watch<LidarService>();
    final (dispX, dispY, dispYaw, trajectory) =
        context.select<RobotStatus, (double, double, double, List<Offset>)>(
      (s) => (s.displayX, s.displayY, s.displayYaw, s.trajectory),
    );

    final effectivePanX =
        _followRobot ? dispY * _scale : _pan.dx;
    final effectivePanY =
        _followRobot ? dispX * _scale : _pan.dy;

    return GestureDetector(
      onScaleStart: (_) {
        _initialScale = _scale;
        if (_followRobot) {
          _pan = Offset(effectivePanX, effectivePanY);
          _followRobot = false;
        }
      },
      onScaleUpdate: (details) {
        setState(() {
          _pan += details.focalPointDelta;
          _scale = (_initialScale * details.scale).clamp(10.0, 200.0);
        });
      },
      onDoubleTap: _resetView,
      child: ColoredBox(
        color: const Color(0xFFF8F8FA),
        child: RepaintBoundary(
          child: CustomPaint(
            painter: OccupancyMapPainter(
              map: mapService.currentMap,
              mapImage: mapService.mapImage,
              scanPoints: lidar.points,
              trajectory: trajectory,
              robotX: dispX,
              robotY: dispY,
              robotYaw: dispYaw,
              scale: _scale,
              panX: effectivePanX,
              panY: effectivePanY,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomControls() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x99E8E8EC), width: 0.6),
        boxShadow: [
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _followRobot = !_followRobot),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: Icon(
                _followRobot
                    ? CupertinoIcons.location_fill
                    : CupertinoIcons.location,
                size: 16,
                color: _followRobot
                    ? const Color(0xFF2563A8)
                    : const Color(0xFFC7C7CC),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 20,
            color: const Color(0xFFE8E8EC),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _scale = (_scale * 1.25).clamp(10.0, 200.0);
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
            height: 20,
            color: const Color(0xFFE8E8EC),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _scale = (_scale / 1.25).clamp(10.0, 200.0);
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
          Container(
            width: 1,
            height: 20,
            color: const Color(0xFFE8E8EC),
          ),
          GestureDetector(
            onTap: _resetView,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.scope,
                size: 16,
                color: Color(0xFF2563A8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar() {
    final mapService = context.watch<MapService>();
    final lidar = context.watch<LidarService>();
    final m = mapService.currentMap;
    final sizeText = m != null ? '${m.width}x${m.height}' : '--';
    final resText = m != null ? '${m.resolution}m' : '--';
    return Positioned(
      bottom: 8,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xCCFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x99E8E8EC), width: 0.6),
          boxShadow: [
            BoxShadow(
              color: const Color(0x14000000),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _infoItem('地图', sizeText),
            _infoItem('分辨率', resText),
            _infoItem('点云', '${lidar.points.length}'),
            _infoItem('缩放', '${_scale.toStringAsFixed(0)}px/m'),
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
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x99E8E8EC), width: 0.6),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A000000),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
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
  const _CanvasPlaceholder({required this.status, this.label = ''});
  final ConnectionStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      ConnectionStatus.connecting => '$label连接中…',
      ConnectionStatus.error => '$label连接失败',
      _ => '$label未连接',
    };
    final icon = status == ConnectionStatus.error
        ? CupertinoIcons.exclamationmark_circle
        : label == '地图'
            ? CupertinoIcons.map
            : CupertinoIcons.location;
    return Container(
      color: const Color(0xFFF2F2F7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
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
