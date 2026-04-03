/// 视口缩放平移状态（与 Web `posX/posY/currentScale` 语义对齐）。
class ViewportPanZoom {
  /// 1..5
  final double scale;

  /// 与 Web 相同的平移（px），配合 `Transform.translate` + 中心 `scale`。
  final double posX;
  final double posY;

  const ViewportPanZoom({
    required this.scale,
    required this.posX,
    required this.posY,
  });
}

/// Web `zoomAtPoint`：以指针为锚点更新 scale 与平移。
ViewportPanZoom zoomAtPoint({
  required double oldScale,
  required double oldPosX,
  required double oldPosY,
  required double newScale,
  required double containerW,
  required double containerH,
  required double pointerLocalX,
  required double pointerLocalY,
}) {
  final clampedNew = newScale.clamp(1.0, 5.0);
  final oldClamped = oldScale.clamp(1.0, 5.0);
  if ((clampedNew - oldClamped).abs() < 1e-9) {
    return ViewportPanZoom(scale: oldClamped, posX: oldPosX, posY: oldPosY);
  }
  final cx = containerW / 2;
  final cy = containerH / 2;
  final pX = pointerLocalX;
  final pY = pointerLocalY;
  final scaledPointX = (pX - cx - oldPosX) / oldClamped;
  final scaledPointY = (pY - cy - oldPosY) / oldClamped;
  final nPosX = pX - cx - scaledPointX * clampedNew;
  final nPosY = pY - cy - scaledPointY * clampedNew;
  return ViewportPanZoom(scale: clampedNew, posX: nPosX, posY: nPosY);
}

/// Web `updateTransform` 边界约束：内容铺满视口、无黑边。
ViewportPanZoom clampPan({
  required double scale,
  required double posX,
  required double posY,
  required double containerW,
  required double containerH,
  required double contentW,
  required double contentH,
}) {
  var s = scale.clamp(1.0, 5.0);
  var px = posX;
  var py = posY;

  if (s <= 1.0) {
    return const ViewportPanZoom(scale: 1, posX: 0, posY: 0);
  }

  final scaledW = contentW * s;
  final scaledH = contentH * s;
  final cx = containerW / 2;
  final cy = containerH / 2;
  final minX = cx - scaledW / 2;
  final maxX = cx + scaledW / 2 - containerW;
  final minY = cy - scaledH / 2;
  final maxY = cy + scaledH / 2 - containerH;

  if (scaledW <= containerW) {
    px = 0;
  } else {
    px = px.clamp(minX, maxX);
  }

  if (scaledH <= containerH) {
    py = 0;
  } else {
    py = py.clamp(minY, maxY);
  }

  return ViewportPanZoom(scale: s, posX: px, posY: py);
}

/// 滚轮步进系数（Web：`deltaY > 0 ? 0.9 : 1.1`）。
double wheelScaleMultiplier(double scrollDeltaY) {
  return scrollDeltaY > 0 ? 0.9 : 1.1;
}
