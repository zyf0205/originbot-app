import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../config/ip_history.dart';
import '../models/robot_status.dart';
import '../services/control_service.dart';
import '../services/lidar_service.dart';
import '../services/video_service.dart';
import '../widgets/connection_indicator.dart';
import '../widgets/joystick_control.dart';
import '../widgets/speed_sliders.dart';
import '../widgets/status_panel.dart';
import '../widgets/video_view.dart';
import 'lidar_map_tab.dart';
import 'odom_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _ipCtrl;
  late final CupertinoTabController _tabController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ipCtrl = TextEditingController(text: context.read<ControlService>().ip);
    _tabController = CupertinoTabController();
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    final index = _tabController.index;
    final control = context.read<ControlService>();
    final video = context.read<VideoService>();

    if (control.status.controlStatus != ConnectionStatus.connected) return;

    if (index == 0) {
      if (video.status.videoStatus == ConnectionStatus.disconnected ||
          video.status.videoStatus == ConnectionStatus.error) {
        video.connect();
      }
    } else {
      if (video.status.videoStatus == ConnectionStatus.connected) {
        video.disconnect();
      }
    }
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
    final video = context.read<VideoService>();
    final lidar = context.read<LidarService>();
    control.setIp(ip);
    video.setIp(ip);
    lidar.setIp(ip);
    IpHistory.add(ip);
    control.connect();
    video.connect();
    lidar.connect();
  }

  void _disconnect() {
    context.read<ControlService>().disconnect();
    context.read<VideoService>().disconnect();
    context.read<LidarService>().disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<RobotStatus>();
    final isConnected = status.controlStatus == ConnectionStatus.connected ||
        status.videoStatus == ConnectionStatus.connected ||
        status.lidarStatus == ConnectionStatus.connected;
    final connecting = status.controlStatus == ConnectionStatus.connecting ||
        status.videoStatus == ConnectionStatus.connecting ||
        status.lidarStatus == ConnectionStatus.connecting;

    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.game_controller),
            label: '遥控',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.map),
            label: '地图',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.location),
            label: '里程',
          ),
        ],
      ),
      tabBuilder: (context, index) {
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
          child: switch (index) {
            0 => _ControlTab(
                ipCtrl: _ipCtrl,
                error: _error,
                connecting: connecting,
                onIpChanged: (text) {
                  context.read<ControlService>().setIp(text);
                  if (_error != null) setState(() => _error = null);
                },
              ),
            1 => const LidarMapTab(),
            2 => const OdomTab(),
            _ => const SizedBox(),
          },
        );
      },
    );
  }
}

class _ControlTab extends StatelessWidget {
  const _ControlTab({
    required this.ipCtrl,
    required this.error,
    required this.connecting,
    required this.onIpChanged,
  });

  final TextEditingController ipCtrl;
  final String? error;
  final bool connecting;
  final ValueChanged<String> onIpChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildConnectionCard(),
          const SizedBox(height: 8),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: const VideoView(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const StatusPanel(),
          const SizedBox(height: 8),
          const Expanded(
            flex: 3,
            child: _ControlArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
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
                  controller: ipCtrl,
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
                    border: error != null
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
                  onChanged: onIpChanged,
                ),
              ),
            ],
          ),
          if (error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, left: 22),
                child: Text(
                  error!,
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
}

class _ControlArea extends StatelessWidget {
  const _ControlArea();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
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
          Expanded(
            flex: 5,
            child: JoystickControl(),
          ),
          SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: SpeedSliders(),
          ),
        ],
      ),
    );
  }
}
