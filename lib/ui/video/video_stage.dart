import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'roi_overlay.dart';
import 'scale_ruler_math.dart';
import 'zoom_viewport_math.dart';
import 'zoomable_video_viewport.dart';

/// 显微镜视频舞台组件，负责展示 MJPEG 视频流及顶部 HUD。
class VideoStage extends StatefulWidget {
  /// 创建视频舞台。
  const VideoStage({
    super.key,
    required this.videoUrl,
    required this.isVideoLive,
    required this.onToggleLive,
    required this.onRoiChanged,
    this.videoFrameSize = const Size(640, 480),
    /// `settings_update.pixel_size`（μm/px）；缺省与 Web `script.js` 初值一致。
    this.pixelSizeUmPerPx = 10,
    /// `settings_update.magnification`。
    this.magnification = 20,
  });

  /// 视频流地址。
  final String videoUrl;

  /// 当前是否直播状态（`true` 显示 MJPEG，`false` 显示暂停态）。
  final bool isVideoLive;

  /// 切换直播/暂停状态回调。
  final VoidCallback onToggleLive;

  /// ROI 变化回调，用于上层发送 `roi_norm`。
  final ValueChanged<RoiRectNorm?> onRoiChanged;

  /// 视频原始尺寸（仅用于 `BoxFit.contain` 坐标映射）。
  final Size videoFrameSize;

  /// 像素物理尺寸 μm/px。
  final double pixelSizeUmPerPx;

  /// 物镜倍率。
  final int magnification;

  @override
  State<VideoStage> createState() => _VideoStageState();
}

class _VideoStageState extends State<VideoStage> {
  double _scale = 1;
  double _posX = 0;
  double _posY = 0;
  double _pinchBaseScale = 1;
  double _trackpadPinchBaseScale = 1;

  static const double _roiScaleEpsilon = 0.001;

  void _applyZoomPan(
    ViewportPanZoom z,
    double contentW,
    double contentH,
    double containerW,
    double containerH,
  ) {
    final c = clampPan(
      scale: z.scale,
      posX: z.posX,
      posY: z.posY,
      containerW: containerW,
      containerH: containerH,
      contentW: contentW,
      contentH: contentH,
    );
    setState(() {
      _scale = c.scale;
      _posX = c.posX;
      _posY = c.posY;
    });
  }

  void _onWheel(PointerSignalEvent signal, Size viewportSize) {
    if (signal is! PointerScrollEvent) {
      return;
    }
    final vw = viewportSize.width;
    final vh = viewportSize.height;
    final cr = contentRectForContain(
      stageW: vw,
      stageH: vh,
      imageW: widget.videoFrameSize.width,
      imageH: widget.videoFrameSize.height,
    );
    final m = wheelScaleMultiplier(signal.scrollDelta.dy);
    final target = (_scale * m).clamp(1.0, 5.0);
    final z = zoomAtPoint(
      oldScale: _scale,
      oldPosX: _posX,
      oldPosY: _posY,
      newScale: target,
      containerW: vw,
      containerH: vh,
      pointerLocalX: signal.localPosition.dx,
      pointerLocalY: signal.localPosition.dy,
    );
    _applyZoomPan(z, cr.width, cr.height, vw, vh);
  }

  void _resetZoom(Size viewportSize) {
    final vw = viewportSize.width;
    final vh = viewportSize.height;
    final cr = contentRectForContain(
      stageW: vw,
      stageH: vh,
      imageW: widget.videoFrameSize.width,
      imageH: widget.videoFrameSize.height,
    );
    _applyZoomPan(
      const ViewportPanZoom(scale: 1, posX: 0, posY: 0),
      cr.width,
      cr.height,
      vw,
      vh,
    );
  }

  void _onScaleUpdate(ScaleUpdateDetails d, Size viewportSize) {
    final vw = viewportSize.width;
    final vh = viewportSize.height;
    final cr = contentRectForContain(
      stageW: vw,
      stageH: vh,
      imageW: widget.videoFrameSize.width,
      imageH: widget.videoFrameSize.height,
    );
    final pc = d.pointerCount;
    final isPinch = pc > 1 || (d.scale - 1.0).abs() > 1e-6;
    if (isPinch) {
      final target = (_pinchBaseScale * d.scale).clamp(1.0, 5.0);
      final z = zoomAtPoint(
        oldScale: _scale,
        oldPosX: _posX,
        oldPosY: _posY,
        newScale: target,
        containerW: vw,
        containerH: vh,
        pointerLocalX: d.localFocalPoint.dx,
        pointerLocalY: d.localFocalPoint.dy,
      );
      _applyZoomPan(z, cr.width, cr.height, vw, vh);
    } else if (_scale > 1.0) {
      final delta = d.focalPointDelta;
      final z = ViewportPanZoom(
        scale: _scale,
        posX: _posX + delta.dx,
        posY: _posY + delta.dy,
      );
      _applyZoomPan(z, cr.width, cr.height, vw, vh);
    }
  }

  void _onPointerPanZoomUpdate(PointerPanZoomUpdateEvent e, Size viewportSize) {
    final vw = viewportSize.width;
    final vh = viewportSize.height;
    final cr = contentRectForContain(
      stageW: vw,
      stageH: vh,
      imageW: widget.videoFrameSize.width,
      imageH: widget.videoFrameSize.height,
    );
    final target = (_trackpadPinchBaseScale * e.scale).clamp(1.0, 5.0);
    var z = zoomAtPoint(
      oldScale: _scale,
      oldPosX: _posX,
      oldPosY: _posY,
      newScale: target,
      containerW: vw,
      containerH: vh,
      pointerLocalX: e.localPosition.dx,
      pointerLocalY: e.localPosition.dy,
    );
    if (e.localPanDelta.dx != 0 || e.localPanDelta.dy != 0) {
      z = ViewportPanZoom(
        scale: z.scale,
        posX: z.posX + e.localPanDelta.dx,
        posY: z.posY + e.localPanDelta.dy,
      );
    }
    _applyZoomPan(z, cr.width, cr.height, vw, vh);
  }

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
                    widget.videoUrl,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  icon: Icon(widget.isVideoLive ? Icons.pause : Icons.play_arrow),
                  iconSize: 20,
                  tooltip: widget.isVideoLive ? '暂停' : '继续',
                  onPressed: widget.onToggleLive,
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final vw = constraints.maxWidth;
                final vh = constraints.maxHeight;
                final viewportSize = Size(vw, vh);

                return Listener(
                  onPointerSignal: (s) => _onWheel(s, viewportSize),
                  onPointerPanZoomStart: (_) {
                    _trackpadPinchBaseScale = _scale;
                  },
                  onPointerPanZoomUpdate: (e) =>
                      _onPointerPanZoomUpdate(e, viewportSize),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: () => _resetZoom(viewportSize),
                    onScaleStart: (_) {
                      _pinchBaseScale = _scale;
                    },
                    onScaleUpdate: (d) => _onScaleUpdate(d, viewportSize),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ZoomableVideoViewport(
                          videoUrl: widget.videoUrl,
                          isVideoLive: widget.isVideoLive,
                          videoFrameSize: widget.videoFrameSize,
                          scale: _scale,
                          posX: _posX,
                          posY: _posY,
                          pixelSizeUmPerPx: widget.pixelSizeUmPerPx,
                          magnification: widget.magnification,
                          errorBuilder: (context, error, stack) => Center(
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
                        ),
                        if (_scale <= 1.0 + _roiScaleEpsilon)
                          RoiOverlay(
                            imageSize: widget.videoFrameSize,
                            onRoiChanged: widget.onRoiChanged,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
