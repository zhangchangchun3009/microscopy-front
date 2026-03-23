/// 聊天面板宽度模型。
///
/// 负责维护面板的比例宽度、折叠状态，以及在窗口变化/拖拽时的合法化。
class ChatPanelWidthModel {
  /// 默认展开宽度比例。
  static const double defaultFactor = 0.30;

  /// 允许的最大宽度比例（相对窗口宽度）。
  static const double maxFactor = 0.50;

  /// 原始最小像素宽度，窄屏时会与 maxWidth 取较小值。
  static const double rawMinWidthPx = 320;

  /// 当前面板宽度比例（私有存储）。
  double _currentFactor;

  /// 最近一次展开时的宽度比例（私有存储）。
  double _lastExpandedFactor;

  /// 是否处于折叠状态（私有存储）。
  bool _collapsed;

  /// 当前面板宽度比例（只读）。
  double get currentFactor => _currentFactor;

  /// 最近一次展开时的宽度比例（只读）。
  double get lastExpandedFactor => _lastExpandedFactor;

  /// 是否处于折叠状态（只读）。
  bool get collapsed => _collapsed;

  /// 创建宽度模型。
  ///
  /// [currentFactor] 当前比例；[lastExpandedFactor] 最近展开比例；
  /// [collapsed] 折叠标记。
  ChatPanelWidthModel({
    double? currentFactor,
    double? lastExpandedFactor,
    bool collapsed = false,
  }) : _currentFactor = _sanitizeFactor(currentFactor),
       _lastExpandedFactor = _sanitizeFactor(lastExpandedFactor),
       _collapsed = collapsed;

  /// 应用拖拽偏移并更新当前比例。
  ///
  /// [windowWidth] 为可布局宽度；[deltaDx] 为手势原始 dx（像素）。
  void applyDrag({required double windowWidth, required double deltaDx}) {
    if (_collapsed || windowWidth <= 0) {
      return;
    }
    // 规格约束：targetWidth = oldWidth - deltaDx
    final targetWidth = _currentFactor * windowWidth - deltaDx;
    _currentFactor = _clampedFactorForWidth(windowWidth, targetWidth);
  }

  /// 折叠面板，并在折叠动作内聚保存合法化后的展开宽度。
  ///
  /// [windowWidth] 为可布局宽度。
  void collapse(double windowWidth) {
    if (windowWidth > 0) {
      final currentWidth = _currentFactor * windowWidth;
      _lastExpandedFactor = _clampedFactorForWidth(windowWidth, currentWidth);
    } else {
      // 非法窗口宽度下仍保证历史值不超过上界。
      _lastExpandedFactor = _sanitizeFactor(
        _lastExpandedFactor,
      ).clamp(0.0, maxFactor);
    }
    _collapsed = true;
  }

  /// 展开面板并恢复最近展开宽度。
  void expand() {
    _collapsed = false;
    _currentFactor = _lastExpandedFactor;
  }

  /// 在窗口尺寸变化后，同时合法化当前宽度和记忆宽度。
  void clampForWindow(double windowWidth) {
    if (windowWidth <= 0) {
      return;
    }
    final currentWidth = _currentFactor * windowWidth;
    final lastWidth = _lastExpandedFactor * windowWidth;
    _currentFactor = _clampedFactorForWidth(windowWidth, currentWidth);
    _lastExpandedFactor = _clampedFactorForWidth(windowWidth, lastWidth);
  }

  /// 将当前宽度保存为最近展开宽度（折叠态不保存）。
  void saveExpandedWidth() {
    if (!_collapsed) {
      _lastExpandedFactor = _currentFactor;
    }
  }

  /// 受控更新当前比例（自动合法化非法输入）。
  void setCurrentFactor(double? factor) {
    _currentFactor = _sanitizeFactor(factor).clamp(0.0, maxFactor);
  }

  /// 受控更新展开记忆比例（自动合法化非法输入）。
  void setLastExpandedFactor(double? factor) {
    _lastExpandedFactor = _sanitizeFactor(factor).clamp(0.0, maxFactor);
  }

  double _clampedFactorForWidth(double windowWidth, double targetWidth) {
    final maxWidth = maxFactor * windowWidth;
    final effectiveMinWidth = rawMinWidthPx < maxWidth
        ? rawMinWidthPx
        : maxWidth;
    final clampedWidth = targetWidth
        .clamp(effectiveMinWidth, maxWidth)
        .toDouble();
    return clampedWidth / windowWidth;
  }

  static double _sanitizeFactor(double? factor) {
    if (factor == null || !factor.isFinite || factor <= 0) {
      return defaultFactor;
    }
    return factor > maxFactor ? maxFactor : factor;
  }
}
