import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

/// Native (non-Web) MJPEG 视频源实现。
///
/// 使用 [Mjpeg] 插件渲染 MJPEG 流，依赖 `dart:io`，不支持 Web 编译。
Widget buildMjpegView({
  required String videoUrl,
  Widget Function(BuildContext, dynamic, dynamic)? errorBuilder,
}) {
  return Mjpeg(
    stream: videoUrl,
    isLive: true,
    timeout: const Duration(seconds: 60),
    fit: BoxFit.contain,
    error: errorBuilder ??
        (context, error, stack) => Center(
              child: Text('视频连接失败: $error'),
            ),
  );
}
