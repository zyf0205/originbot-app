import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../config/ip_history.dart';
import '../models/robot_status.dart';
import '../services/control_service.dart';
import '../services/video_service.dart';
import '../widgets/connection_indicator.dart';
import '../widgets/joystick_control.dart';
import '../widgets/speed_sliders.dart';
import '../widgets/status_panel.dart';
import '../widgets/video_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _ipCtrl;
  String? _error;

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
    final video = context.read<VideoService>();
    control.setIp(ip);
    video.setIp(ip);
    IpHistory.add(ip);
    control.connect();
    video.connect();
  }

  void _disconnect() {
    context.read<ControlService>().disconnect();
    context.read<VideoService>().disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<RobotStatus>();
    final isConnected = status.controlStatus == ConnectionStatus.connected ||
        status.videoStatus == ConnectionStatus.connected;
    final connecting = status.controlStatus == ConnectionStatus.connecting ||
        status.videoStatus == ConnectionStatus.connecting;

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
            _buildConnectionCard(connecting),
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
      ),
    );
  }

  Widget _buildConnectionCard(bool connecting) {
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
