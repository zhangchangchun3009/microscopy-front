import 'dart:math' as math;

/// 与 Web `getNiceLengthGlobal` 一致的候选长度序列（单位 μm）。
const List<double> kNiceLengthsUm = [
  1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000,
];

/// 选取与 [targetUm] 最接近的“整齐”长度（μm）。
double pickNiceLengthUm(double targetUm) {
  if (!targetUm.isFinite || targetUm <= 0) {
    return kNiceLengthsUm.first;
  }
  double best = kNiceLengthsUm.first;
  double bestDiff = (targetUm - best).abs();
  for (final len in kNiceLengthsUm) {
    final diff = (targetUm - len).abs();
    if (diff < bestDiff) {
      best = len;
      bestDiff = diff;
    }
  }
  return best;
}

/// 比例尺的一次计算结果（显示用）。
class RulerDisplay {
  /// 整齐后的物理长度（μm）。
  final double niceLengthUm;

  /// 标尺线段在屏幕上的长度（px）。
  final double rulerLengthPx;

  const RulerDisplay({
    required this.niceLengthUm,
    required this.rulerLengthPx,
  });
}

/// 与 `microscopy_server/static/js/script.js` 中 `updateRuler` / `updateMainCameraRuler` 对齐：
///
/// - `actualPixelSize = pixelSize / magnification`
/// - `scaledPixelSize = actualPixelSize / scale`
/// - `targetRulerWidth = containerWidth * 0.2`
/// - `rulerLengthUm = targetRulerWidth * scaledPixelSize`
///
/// [containerWidthPx] 对应 Web 的 `container.getBoundingClientRect().width`（视频区域整体宽度，
/// Flutter 即视口 [LayoutBuilder] 的宽）；随分栏拖拽、全屏、窗口缩放变化。
RulerDisplay? computeRulerDisplay({
  required double pixelSizeUmPerPx,
  required int magnification,
  required double viewportScale,
  required double containerWidthPx,
}) {
  if (magnification <= 0 || !pixelSizeUmPerPx.isFinite || pixelSizeUmPerPx <= 0) {
    return null;
  }
  if (!viewportScale.isFinite || viewportScale <= 0) {
    return null;
  }
  if (!containerWidthPx.isFinite || containerWidthPx <= 0) {
    return null;
  }
  final actualPixelSize = pixelSizeUmPerPx / magnification;
  final scaledPixelSize = actualPixelSize / viewportScale;
  final targetRulerWidthPx = containerWidthPx * 0.2;
  final rulerLengthUm = targetRulerWidthPx * scaledPixelSize;
  final niceLengthUm = pickNiceLengthUm(rulerLengthUm);
  final finalRulerLengthPx = niceLengthUm / scaledPixelSize;
  return RulerDisplay(
    niceLengthUm: niceLengthUm,
    rulerLengthPx: finalRulerLengthPx,
  );
}

/// 格式化标尺标签（与 Web 一致：≥1000 μm 用 mm）。
String formatRulerLabel(double niceLengthUm) {
  if (niceLengthUm >= 1000) {
    return '${(niceLengthUm / 1000).toStringAsFixed(1)} mm';
  }
  return '${niceLengthUm.toStringAsFixed(0)} μm';
}

/// `BoxFit.contain` 下图像在舞台中的内容矩形（物理像素与归一化 ROI 设计一致）。
({double left, double top, double width, double height}) contentRectForContain({
  required double stageW,
  required double stageH,
  required double imageW,
  required double imageH,
}) {
  if (stageW <= 0 || stageH <= 0 || imageW <= 0 || imageH <= 0) {
    return (left: 0, top: 0, width: stageW, height: stageH);
  }
  final scale = math.min(stageW / imageW, stageH / imageH);
  final cw = imageW * scale;
  final ch = imageH * scale;
  final ox = (stageW - cw) / 2;
  final oy = (stageH - ch) / 2;
  return (left: ox, top: oy, width: cw, height: ch);
}
