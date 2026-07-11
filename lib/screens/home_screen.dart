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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<RobotStatus>();
    final control = context.watch<ControlService>();
    final isConnected = status.controlStatus == ConnectionStatus.connected ||
        status.videoStatus == ConnectionStatus.connected;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('OriginBot'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ConnectionIndicator(),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: isConnected
                  ? () {
                      control.disconnect();
                      context.read<VideoService>().disconnect();
                    }
                  : () => _connectAll(context),
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
            const _ConnectionCard(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: const AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [VideoView()],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const StatusPanel(),
            const SizedBox(height: 8),
            const Expanded(
              child: _ControlArea(),
            ),
          ],
        ),
      ),
    );
  }

  void _connectAll(BuildContext context) {
    final ip = context.read<ControlService>().ip;
    if (ip.isEmpty) return;
    context.read<VideoService>().setIp(ip);
    context.read<ControlService>().connect();
    context.read<VideoService>().connect();
  }
}

class _ControlArea extends StatelessWidget {
  const _ControlArea();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            flex: 5,
            child: JoystickControl(),
          ),
          const SizedBox(width: 12),
          const Expanded(
            flex: 4,
            child: SpeedSliders(),
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatefulWidget {
  const _ConnectionCard();

  @override
  State<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<_ConnectionCard> {
  late final TextEditingController _ipCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final saved = context.read<ControlService>().ip;
    _ipCtrl = TextEditingController(text: saved);
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    super.dispose();
  }

  void _connect() {
    final ip = _ipCtrl.text.trim();
    final err = context.read<ControlService>().validateIp(ip);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() => _error = null);
    IpHistory.add(ip);
    final control = context.read<ControlService>();
    final video = context.read<VideoService>();
    control.setIp(ip);
    video.setIp(ip);
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
    final cs = status.controlStatus;
    final connected =
        cs == ConnectionStatus.connected || status.videoStatus == ConnectionStatus.connected;
    final connecting =
        cs == ConnectionStatus.connecting || status.videoStatus == ConnectionStatus.connecting;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _ipCtrl,
                  placeholder: '机器人 IP',
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enabled: !connecting,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
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
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: connecting
                    ? null
                    : (connected ? _disconnect : _connect),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: connected
                        ? CupertinoColors.systemRed
                        : CupertinoColors.activeBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    connecting ? '…' : (connected ? '断开' : '连接'),
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
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
