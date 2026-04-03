import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

import 'scale_ruler.dart';
import 'scale_ruler_math.dart';

/// 按给定缩放/平移显示 MJPEG 与比例尺（交互由上层处理，避免被 ROI 层拦截）。
///
/// - [scale] / [posX] / [posY] 由 [VideoStage] 根据滚轮、双指、触控板捏合等更新。
/// - 比例尺贴在 `BoxFit.contain`**内容矩形**左下角，避免落在 letterbox 外。
class ZoomableVideoViewport extends StatelessWidget {
  /// 创建视频视口（仅渲染）。
  const ZoomableVideoViewport({
    super.key,
    required this.videoUrl,
    required this.isVideoLive,
    required this.videoFrameSize,
    required this.scale,
    required this.posX,
    required this.posY,
    this.pixelSizeUmPerPx,
    this.magnification,
    this.errorBuilder,
  });

  final String videoUrl;
  final bool isVideoLive;
  final Size videoFrameSize;

  /// 用户缩放 1..5。
  final double scale;

  /// 与 Web 一致的平移（px）。
  final double posX;
  final double posY;

  final double? pixelSizeUmPerPx;
  final int? magnification;

  final Widget Function(BuildContext context, dynamic error, dynamic stack)?
      errorBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vw = constraints.maxWidth;
        final vh = constraints.maxHeight;
        final cr = contentRectForContain(
          stageW: vw,
          stageH: vh,
          imageW: videoFrameSize.width,
          imageH: videoFrameSize.height,
        );

        final videoChild = isVideoLive
            ? Mjpeg(
                stream: videoUrl,
                isLive: true,
                timeout: const Duration(seconds: 60),
                fit: BoxFit.contain,
                error: errorBuilder ??
                    (context, error, stack) => Center(
                          child: Text('视频连接失败: $error'),
                        ),
              )
            : const Center(
                child: Text('视频已暂停', style: TextStyle(color: Colors.white70)),
              );

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Transform.translate(
                  offset: Offset(posX, posY),
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: vw,
                      height: vh,
                      child: videoChild,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: cr.left + 12,
                bottom: vh - cr.top - cr.height + 8,
                child: IgnorePointer(
                  child: ScaleRuler(
                    containerWidthPx: vw,
                    viewportScale: scale,
                    pixelSizeUmPerPx: pixelSizeUmPerPx,
                    magnification: magnification,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
