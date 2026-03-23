import 'package:flutter/material.dart';
import 'package:microscope_app/ui/layout/chat_panel_width_model.dart';

/// 右侧聊天分栏布局：
/// - 默认右栏占比约 30%
/// - 支持折叠为 24px 把手
/// - 支持左边界拖拽调整宽度
class RightChatSplitLayout extends StatefulWidget {
  const RightChatSplitLayout({
    super.key,
    required this.leftPane,
    required this.rightChatPane,
    this.initialChatFraction = 0.3,
  });

  /// 左侧主区域（视频 + HUD）。
  final Widget leftPane;

  /// 右侧聊天区域内容。
  final Widget rightChatPane;

  /// 初始聊天区域占比，默认 30%。
  final double initialChatFraction;

  @override
  State<RightChatSplitLayout> createState() => _RightChatSplitLayoutState();
}

class _RightChatSplitLayoutState extends State<RightChatSplitLayout> {
  static const double _collapsedHandleWidth = 24;
  static const double _dragHandleWidth = 8;

  late final ChatPanelWidthModel _widthModel;

  @override
  void initState() {
    super.initState();
    _widthModel = ChatPanelWidthModel(
      currentFactor: widget.initialChatFraction,
      lastExpandedFactor: widget.initialChatFraction,
    );
  }

  void _toggleChat(double windowWidth) {
    setState(() {
      _widthModel.clampForWindow(windowWidth);
      if (_widthModel.collapsed) {
        _widthModel.expand();
      } else {
        _widthModel.collapse(windowWidth);
      }
    });
  }

  /// 响应左边界拖拽：
  /// - 使用规格公式 targetWidth = oldWidth - deltaDx
  /// - 具体 clamp 规则由 [ChatPanelWidthModel] 统一维护
  void _onResizeDragUpdate(DragUpdateDetails details, double windowWidth) {
    if (_widthModel.collapsed) {
      return;
    }
    setState(() {
      // 仅在交互事件中写入状态，避免 build() 产生副作用。
      _widthModel.clampForWindow(windowWidth);
      _widthModel.applyDrag(windowWidth: windowWidth, deltaDx: details.delta.dx);
      _widthModel.saveExpandedWidth();
    });
  }

  /// 计算用于当前帧渲染的宽度（纯计算，无状态写入）。
  double _effectiveChatWidthForRender(double windowWidth) {
    if (windowWidth <= 0) {
      return 0;
    }
    final maxWidth = ChatPanelWidthModel.maxFactor * windowWidth;
    final minWidth = ChatPanelWidthModel.rawMinWidthPx < maxWidth
        ? ChatPanelWidthModel.rawMinWidthPx
        : maxWidth;
    final preferredWidth = _widthModel.currentFactor * windowWidth;
    return preferredWidth.clamp(minWidth, maxWidth).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final windowWidth = constraints.maxWidth;
        final chatWidth = _effectiveChatWidthForRender(windowWidth);
        final rightWidth = _widthModel.collapsed ? _collapsedHandleWidth : chatWidth;
        final leftWidth = (constraints.maxWidth - rightWidth).clamp(0.0, double.infinity);

        return Row(
          children: [
            SizedBox(width: leftWidth, child: widget.leftPane),
            _widthModel.collapsed
                ? SizedBox(
                    key: const ValueKey('right-chat-collapsed-handle'),
                    width: _collapsedHandleWidth,
                    child: InkWell(
                      key: const ValueKey('right-chat-toggle-handle'),
                      onTap: () => _toggleChat(windowWidth),
                      child: const Center(
                        child: Icon(Icons.chevron_left, size: 18),
                      ),
                    ),
                  )
                : SizedBox(
                    key: const ValueKey('right-chat-panel'),
                    width: rightWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MouseRegion(
                          cursor: SystemMouseCursors.resizeLeftRight,
                          child: GestureDetector(
                            key: const ValueKey('right-chat-drag-handle'),
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragUpdate: (details) =>
                                _onResizeDragUpdate(details, windowWidth),
                            child: Container(
                              width: _dragHandleWidth,
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              widget.rightChatPane,
                              Positioned(
                                left: -8,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: InkWell(
                                    key: const ValueKey('right-chat-toggle-handle'),
                                    onTap: () => _toggleChat(windowWidth),
                                    child: const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Icon(Icons.chevron_right, size: 18),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ],
        );
      },
    );
  }
}
