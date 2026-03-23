import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

/// 显微镜视频舞台组件，负责展示 MJPEG 视频流及顶部 HUD。
class VideoStage extends StatelessWidget {
  const VideoStage({
    super.key,
    required this.videoUrl,
    required this.isVideoLive,
    required this.onToggleLive,
  });

  /// 视频流地址。
  final String videoUrl;

  /// 当前是否直播状态（`true` 显示 MJPEG，`false` 显示暂停态）。
  final bool isVideoLive;

  /// 切换直播/暂停状态回调。
  final VoidCallback onToggleLive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('video-stage'),
      color: Colors.black,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: cs.surfaceContainerHighest,
            child: Row(
              children: [
                const Icon(Icons.videocam, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    videoUrl,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  icon: Icon(isVideoLive ? Icons.pause : Icons.play_arrow),
                  iconSize: 20,
                  tooltip: isVideoLive ? '暂停' : '继续',
                  onPressed: onToggleLive,
                ),
              ],
            ),
          ),
          Expanded(
            child: isVideoLive
                ? Mjpeg(
                    stream: videoUrl,
                    isLive: true,
                    timeout: const Duration(seconds: 60),
                    fit: BoxFit.contain,
                    error: (context, error, stack) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam_off, size: 48, color: cs.error),
                          const SizedBox(height: 12),
                          Text('视频连接失败', style: TextStyle(color: cs.error)),
                          const SizedBox(height: 4),
                          SelectableText(
                            error.toString(),
                            style:
                                Theme.of(context).textTheme.bodySmall ??
                                const TextStyle(),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pause_circle_filled,
                          size: 48,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '视频已暂停',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
