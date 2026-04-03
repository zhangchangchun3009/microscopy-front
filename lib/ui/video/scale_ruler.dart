import 'package:flutter/material.dart';

import 'scale_ruler_math.dart';

/// 左下角像素–物理比例尺（与 Web `.scale-ruler` / `updateRuler` 计算对齐）。
///
/// [containerWidthPx] 为视频视口整体宽度（逻辑像素），与 Web `videoContainer.getBoundingClientRect().width`
/// 同语义，随窗口与右栏宽度变化。
class ScaleRuler extends StatelessWidget {
  /// 创建比例尺覆盖层。
  const ScaleRuler({
    super.key,
    required this.containerWidthPx,
    required this.viewportScale,
    this.pixelSizeUmPerPx,
    this.magnification,
  });

  /// 视频视口宽度（逻辑 px）；用于目标条带宽度 ≈ 20%。
  final double containerWidthPx;

  /// 用户缩放倍数 1..5。
  final double viewportScale;

  /// `settings_update.pixel_size`（μm/px）；缺省则比例尺显示 `--`。
  final double? pixelSizeUmPerPx;

  /// `settings_update.magnification`。
  final int? magnification;

  @override
  Widget build(BuildContext context) {
    final ps = pixelSizeUmPerPx;
    final mag = magnification;
    if (ps == null || mag == null || mag <= 0 || !ps.isFinite || ps <= 0) {
      return const _RulerChrome(label: '--', lineWidth: 48);
    }
    final disp = computeRulerDisplay(
      pixelSizeUmPerPx: ps,
      magnification: mag,
      viewportScale: viewportScale,
      containerWidthPx: containerWidthPx,
    );
    if (disp == null) {
      return const _RulerChrome(label: '--', lineWidth: 48);
    }
    return _RulerChrome(
      label: formatRulerLabel(disp.niceLengthUm),
      lineWidth: disp.rulerLengthPx.clamp(8.0, containerWidthPx),
    );
  }
}

class _RulerChrome extends StatelessWidget {
  const _RulerChrome({required this.label, required this.lineWidth});

  final String label;
  final double lineWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black26),
            boxShadow: const [
              BoxShadow(blurRadius: 4, color: Colors.black26),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'Courier',
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 4,
          width: lineWidth,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1A1A1A),
                Color(0xFF1A1A1A),
                Colors.transparent,
                Colors.transparent,
                Color(0xFF1A1A1A),
                Color(0xFF1A1A1A),
              ],
              stops: [0, 0.1, 0.1, 0.9, 0.9, 1],
            ),
            border: Border(
              top: BorderSide(color: Color(0xFF1A1A1A), width: 2),
              bottom: BorderSide(color: Color(0xFF1A1A1A), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
