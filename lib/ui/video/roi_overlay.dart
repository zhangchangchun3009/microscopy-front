import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 单矩形 ROI 的归一化表示，取值范围均为 `[0,1]`。
class RoiRectNorm {
  /// 构造一个归一化矩形 ROI。
  const RoiRectNorm({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  /// 左上角 x（归一化）。
  final double x;

  /// 左上角 y（归一化）。
  final double y;

  /// 宽度（归一化）。
  final double w;

  /// 高度（归一化）。
  final double h;

  /// 右边界（归一化）。
  double get right => x + w;

  /// 下边界（归一化）。
  double get bottom => y + h;

  /// 返回一个裁剪到合法范围的新 ROI。
  RoiRectNorm normalized() {
    final nx = x.clamp(0.0, 1.0);
    final ny = y.clamp(0.0, 1.0);
    final nr = right.clamp(nx, 1.0);
    final nb = bottom.clamp(ny, 1.0);
    return RoiRectNorm(x: nx, y: ny, w: nr - nx, h: nb - ny);
  }

  /// 转换为 WebSocket 协议 `roi_norm` 负载。
  Map<String, dynamic> toPayload() {
    return {
      'type': 'rect',
      'coords_norm': {'x': x, 'y': y, 'w': w, 'h': h},
    };
  }

  /// 复制并按需覆写字段。
  RoiRectNorm copyWith({double? x, double? y, double? w, double? h}) {
    return RoiRectNorm(
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
    );
  }
}

enum _HandleCorner { topLeft, topRight, bottomLeft, bottomRight }

/// 在视频显示层提供单矩形 ROI 交互（创建/选中/平移/缩放/清除）。
class RoiOverlay extends StatefulWidget {
  /// 创建 ROI 交互层。
  const RoiOverlay({
    super.key,
    required this.imageSize,
    required this.onRoiChanged,
    this.minEdgePx = 12,
  });

  /// 原图尺寸，用于 `BoxFit.contain` 映射与 letterbox 处理。
  final Size imageSize;

  /// ROI 变化回调；清除时传 `null`。
  final ValueChanged<RoiRectNorm?> onRoiChanged;

  /// 最小边长像素阈值（显示坐标系）。
  final double minEdgePx;

  @override
  State<RoiOverlay> createState() => _RoiOverlayState();
}

class _RoiOverlayState extends State<RoiOverlay> {
  RoiRectNorm? _roi;
  RoiRectNorm? _drawingBackupRoi;
  RoiRectNorm? _draftRoi;
  Offset? _drawStartNorm;
  bool _selected = false;

  /// 跟踪当前触摸指针数量，用于区分单指绘制 vs 多指缩放。
  int _pointerCount = 0;
  int? _drawPointerId;

  Rect _contentRect(Size stageSize) {
    if (stageSize.width <= 0 ||
        stageSize.height <= 0 ||
        widget.imageSize.width <= 0 ||
        widget.imageSize.height <= 0) {
      return Offset.zero & stageSize;
    }
    final scale = math.min(
      stageSize.width / widget.imageSize.width,
      stageSize.height / widget.imageSize.height,
    );
    final contentWidth = widget.imageSize.width * scale;
    final contentHeight = widget.imageSize.height * scale;
    final offsetX = (stageSize.width - contentWidth) / 2;
    final offsetY = (stageSize.height - contentHeight) / 2;
    return Rect.fromLTWH(offsetX, offsetY, contentWidth, contentHeight);
  }

  Offset _stageToNorm(Offset stagePoint, Rect contentRect) {
    final cx = (stagePoint.dx - contentRect.left).clamp(0.0, contentRect.width);
    final cy = (stagePoint.dy - contentRect.top).clamp(0.0, contentRect.height);
    return Offset(
      contentRect.width == 0 ? 0 : cx / contentRect.width,
      contentRect.height == 0 ? 0 : cy / contentRect.height,
    );
  }

  Rect _normToStageRect(RoiRectNorm roi, Rect contentRect) {
    return Rect.fromLTWH(
      contentRect.left + roi.x * contentRect.width,
      contentRect.top + roi.y * contentRect.height,
      roi.w * contentRect.width,
      roi.h * contentRect.height,
    );
  }

  RoiRectNorm _roiFromTwoPoints(Offset a, Offset b) {
    final x0 = math.min(a.dx, b.dx).clamp(0.0, 1.0);
    final y0 = math.min(a.dy, b.dy).clamp(0.0, 1.0);
    final x1 = math.max(a.dx, b.dx).clamp(0.0, 1.0);
    final y1 = math.max(a.dy, b.dy).clamp(0.0, 1.0);
    return RoiRectNorm(x: x0, y: y0, w: x1 - x0, h: y1 - y0);
  }

  bool _isLargeEnough(RoiRectNorm roi, Rect contentRect) {
    return roi.w * contentRect.width >= widget.minEdgePx &&
        roi.h * contentRect.height >= widget.minEdgePx;
  }

  void _emitRoi(RoiRectNorm? roi) {
    widget.onRoiChanged(roi?.normalized());
  }

  void _startDraw(Offset local, Rect contentRect) {
    setState(() {
      _drawingBackupRoi = _roi;
      _selected = false;
      _drawStartNorm = _stageToNorm(local, contentRect);
      _draftRoi = _roiFromTwoPoints(_drawStartNorm!, _drawStartNorm!);
      _roi = _draftRoi;
    });
  }

  void _updateDraw(Offset local, Rect contentRect) {
    final start = _drawStartNorm;
    if (start == null) {
      return;
    }
    final current = _stageToNorm(local, contentRect);
    setState(() {
      _draftRoi = _roiFromTwoPoints(start, current);
      _roi = _draftRoi;
    });
  }

  void _endDraw(Rect contentRect) {
    final candidate = _draftRoi;
    final fallback = _drawingBackupRoi;
    setState(() {
      if (candidate != null && _isLargeEnough(candidate, contentRect)) {
        _roi = candidate.normalized();
        _emitRoi(_roi);
      } else {
        _roi = fallback;
      }
      _draftRoi = null;
      _drawStartNorm = null;
      _drawingBackupRoi = null;
    });
  }

  void _moveRoi(DragUpdateDetails details, Rect contentRect) {
    final current = _roi;
    if (current == null || !_selected) {
      return;
    }
    final dxNorm = contentRect.width == 0 ? 0 : details.delta.dx / contentRect.width;
    final dyNorm = contentRect.height == 0 ? 0 : details.delta.dy / contentRect.height;
    final nextX = (current.x + dxNorm).clamp(0.0, 1.0 - current.w);
    final nextY = (current.y + dyNorm).clamp(0.0, 1.0 - current.h);
    final next = current.copyWith(x: nextX, y: nextY);
    setState(() => _roi = next);
    _emitRoi(next);
  }

  void _resizeFromCorner(
    _HandleCorner corner,
    DragUpdateDetails details,
    Rect contentRect,
  ) {
    final current = _roi;
    if (current == null || !_selected) {
      return;
    }
    final minW = contentRect.width == 0 ? 0 : widget.minEdgePx / contentRect.width;
    final minH = contentRect.height == 0 ? 0 : widget.minEdgePx / contentRect.height;
    final dxNorm = contentRect.width == 0 ? 0 : details.delta.dx / contentRect.width;
    final dyNorm = contentRect.height == 0 ? 0 : details.delta.dy / contentRect.height;

    double left = current.x;
    double top = current.y;
    double right = current.right;
    double bottom = current.bottom;

    switch (corner) {
      case _HandleCorner.topLeft:
        left = (left + dxNorm).clamp(0.0, right - minW);
        top = (top + dyNorm).clamp(0.0, bottom - minH);
        break;
      case _HandleCorner.topRight:
        right = (right + dxNorm).clamp(left + minW, 1.0);
        top = (top + dyNorm).clamp(0.0, bottom - minH);
        break;
      case _HandleCorner.bottomLeft:
        left = (left + dxNorm).clamp(0.0, right - minW);
        bottom = (bottom + dyNorm).clamp(top + minH, 1.0);
        break;
      case _HandleCorner.bottomRight:
        right = (right + dxNorm).clamp(left + minW, 1.0);
        bottom = (bottom + dyNorm).clamp(top + minH, 1.0);
        break;
    }

    final next = RoiRectNorm(x: left, y: top, w: right - left, h: bottom - top);
    setState(() => _roi = next);
    _emitRoi(next);
  }

  Widget _buildHandle({
    required String keyName,
    required Alignment alignment,
    required _HandleCorner corner,
    required Rect contentRect,
  }) {
    const size = 16.0;
    return Align(
      alignment: alignment,
      child: GestureDetector(
        key: ValueKey(keyName),
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => _resizeFromCorner(corner, d, contentRect),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 1),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stageSize = Size(constraints.maxWidth, constraints.maxHeight);
        final contentRect = _contentRect(stageSize);
        final roi = _roi;
        final roiStageRect = roi == null ? null : _normToStageRect(roi, contentRect);

        return Stack(
          children: [
            Positioned.fill(
              /// 使用 Listener 而非 GestureDetector，避免与父级 Scale 手势
              /// 在 gesture arena 中竞争。触摸屏上 GestureDetector 的 Pan 会
              /// 在第一根手指落下时立即认领手势，导致双指缩放无法触发。
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) {
                  _pointerCount++;
                  if (_pointerCount == 1 && _drawPointerId == null) {
                    _drawPointerId = e.pointer;
                    _startDraw(e.localPosition, contentRect);
                  }
                },
                onPointerMove: (e) {
                  if (e.pointer == _drawPointerId && _pointerCount == 1) {
                    _updateDraw(e.localPosition, contentRect);
                  }
                },
                onPointerUp: (e) {
                  if (e.pointer == _drawPointerId) {
                    _endDraw(contentRect);
                    _drawPointerId = null;
                  }
                  _pointerCount--;
                },
                onPointerCancel: (e) {
                  if (e.pointer == _drawPointerId) {
                    _endDraw(contentRect);
                    _drawPointerId = null;
                  }
                  _pointerCount--;
                },
              ),
            ),
            if (roiStageRect != null)
              Positioned.fromRect(
                rect: roiStageRect,
                child: GestureDetector(
                  key: const ValueKey('roi-rect'),
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _selected = true),
                  onPanUpdate: (d) => _moveRoi(d, contentRect),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selected ? Colors.redAccent : Colors.red.shade300,
                        width: _selected ? 2.0 : 1.5,
                      ),
                      color: Colors.lightBlueAccent.withOpacity(0.08),
                    ),
                    child: _selected
                        ? Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _buildHandle(
                                keyName: 'roi-handle-tl',
                                alignment: Alignment.topLeft,
                                corner: _HandleCorner.topLeft,
                                contentRect: contentRect,
                              ),
                              _buildHandle(
                                keyName: 'roi-handle-tr',
                                alignment: Alignment.topRight,
                                corner: _HandleCorner.topRight,
                                contentRect: contentRect,
                              ),
                              _buildHandle(
                                keyName: 'roi-handle-bl',
                                alignment: Alignment.bottomLeft,
                                corner: _HandleCorner.bottomLeft,
                                contentRect: contentRect,
                              ),
                              _buildHandle(
                                keyName: 'roi-handle-br',
                                alignment: Alignment.bottomRight,
                                corner: _HandleCorner.bottomRight,
                                contentRect: contentRect,
                              ),
                            ],
                          )
                        : const SizedBox.expand(),
                  ),
                ),
              ),
            if (roiStageRect != null && _selected)
              Positioned(
                left: roiStageRect.right + 8,
                top: roiStageRect.center.dy - 12,
                child: GestureDetector(
                  key: const ValueKey('roi-clear-button'),
                  onTap: () {
                    setState(() {
                      _roi = null;
                      _selected = false;
                    });
                    _emitRoi(null);
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white70),
                    ),
                    child: const Text(
                      '✕',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
