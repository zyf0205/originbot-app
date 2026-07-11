import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../models/robot_status.dart';
import '../services/video_service.dart';

class VideoView extends StatelessWidget {
  const VideoView({super.key});

  @override
  Widget build(BuildContext context) {
    final video = context.watch<VideoService>();
    final videoStatus = context.select<RobotStatus, ConnectionStatus>(
      (s) => s.videoStatus,
    );

    if (videoStatus != ConnectionStatus.connected ||
        video.latestFrame == null) {
      return _Placeholder(status: videoStatus);
    }

    return Image.memory(
      video.latestFrame!,
      gaplessPlayback: true,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.status});
  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final video = context.read<VideoService>();
    final errorMsg =
        context.select<RobotStatus, String?>((s) => s.videoErrorMsg);
    final text = switch (status) {
      ConnectionStatus.connecting => '连接中…',
      ConnectionStatus.connected => '等待画面…',
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
                  : CupertinoIcons.video_camera,
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
                onTap: () => video.connect(),
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
