import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat_models.dart';
import 'chat_turn_models.dart';
import 'system_message_bubble.dart';
import 'turn_bubble.dart';

/// 右侧聊天面板组件。
///
/// 组件只负责 UI 渲染与用户交互事件分发，不持有业务状态。
class ChatPanel extends StatelessWidget {
  /// 创建聊天面板。
  ///
  /// 主要参数：
  /// - [turns] 当前对话 turn 列表（用户和助手消息）；
  /// - [systemMessages] 系统消息列表（通知、警告、进度更新等）；
  /// - [inputController]/[scrollController] 由上层状态持有，确保折叠/展开后状态连续；
  /// - [plainTextMode] 控制气泡视图与纯文本视图切换；
  /// - [onSendMessage]/[onTogglePlainTextMode]/[onCopyAllMessages] 由上层注入行为。
  const ChatPanel({
    super.key,
    required this.turns,
    required this.systemMessages,
    required this.inputController,
    required this.scrollController,
    required this.plainTextMode,
    required this.agentBusy,
    required this.wsConnected,
    required this.plainTextTranscript,
    required this.onTogglePlainTextMode,
    required this.onCopyAllMessages,
    required this.onSendMessage,
    required this.onCancel,
  });

  /// 对话 turn 列表。
  final List<ChatTurn> turns;

  /// 系统消息列表。
  final List<SystemMessage> systemMessages;

  /// 输入框控制器。
  final TextEditingController inputController;

  /// 消息区滚动控制器。
  final ScrollController scrollController;

  /// 是否处于纯文本视图。
  final bool plainTextMode;

  /// Agent 是否正在处理中。
  final bool agentBusy;

  /// WebSocket 是否已连接。
  final bool wsConnected;

  /// 纯文本模式显示的完整转录内容。
  final String plainTextTranscript;

  /// 切换纯文本/气泡视图。
  final VoidCallback onTogglePlainTextMode;

  /// 复制全部消息。
  final VoidCallback onCopyAllMessages;

  /// 发送当前输入消息文本。
  final ValueChanged<String> onSendMessage;

  /// 取消当前正在执行的回合。
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        _buildHeader(cs),
        Expanded(
          child: turns.isEmpty && systemMessages.isEmpty
              ? Center(
                  child: Text(
                    '发送消息开始对话',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              : plainTextMode
              ? _buildPlainTextView(cs)
              : ListView.builder(
                  key: const ValueKey('chat-message-list'),
                  controller: scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: turns.length + systemMessages.length,
                  itemBuilder: (context, i) {
                    // 系统消息显示在前面
                    if (i < systemMessages.length) {
                      return SystemMessageBubble(
                        key: ValueKey('system-msg-${systemMessages[i].time}-$i'),
                        message: systemMessages[i],
                      );
                    }
                    // 对话消息显示在后面
                    final turnIndex = i - systemMessages.length;
                    return TurnBubble(
                      key: ValueKey('turn-${turns[turnIndex].messageId}-$turnIndex'),
                      turn: turns[turnIndex],
                    );
                  },
                ),
        ),
        _ResizableChatComposer(
          colorScheme: cs,
          inputController: inputController,
          wsConnected: wsConnected,
          agentBusy: agentBusy,
          onSendMessage: onSendMessage,
          onCancel: onCancel,
        ),
      ],
    );
  }

  /// 构建聊天面板头部（包含标题、视图切换和复制按钮）
  Widget _buildHeader(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: cs.surfaceContainerHighest,
      child: Row(
        children: [
          const Icon(Icons.chat, size: 18),
          const SizedBox(width: 8),
          const Expanded(child: Text('小微同学')),
          if (turns.isNotEmpty || systemMessages.isNotEmpty) ...[
            IconButton(
              icon: Icon(
                plainTextMode ? Icons.chat_bubble : Icons.text_snippet,
                size: 20,
              ),
              tooltip: plainTextMode ? '切换为气泡视图' : '切换为纯文本（可拖选部分复制）',
              onPressed: onTogglePlainTextMode,
            ),
            IconButton(
              icon: const Icon(Icons.copy_all, size: 20),
              tooltip: '复制全部对话',
              onPressed: onCopyAllMessages,
            ),
          ],
          if (agentBusy)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  /// 构建纯文本视图（整个对话为单一可选中块）
  Widget _buildPlainTextView(ColorScheme cs) {
    return SingleChildScrollView(
      key: const ValueKey('chat-message-list'),
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        plainTextTranscript,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: cs.onSurface,
          height: 1.5,
        ),
      ),
    );
  }

}

/// 可垂直拖动调整高度的输入区：多行编辑 + 顶部拖拽手柄。
///
/// - 初始高度约两行文本，最小约一行，最大避免占满屏幕；
/// - 多行时由发送按钮发送，回车插入换行。
class _ResizableChatComposer extends StatefulWidget {
  const _ResizableChatComposer({
    required this.colorScheme,
    required this.inputController,
    required this.wsConnected,
    required this.agentBusy,
    required this.onSendMessage,
    required this.onCancel,
  });

  final ColorScheme colorScheme;
  final TextEditingController inputController;
  final bool wsConnected;
  final bool agentBusy;
  final ValueChanged<String> onSendMessage;
  final VoidCallback onCancel;

  @override
  State<_ResizableChatComposer> createState() => _ResizableChatComposerState();
}

class _ResizableChatComposerState extends State<_ResizableChatComposer> {
  static const double _minHeight = 52;
  static const double _maxHeight = 320;
  static const double _initialHeight = 88;

  late double _editorHeight;

  @override
  void initState() {
    super.initState();
    _editorHeight = _initialHeight;
  }

  void _onResizeDragUpdate(DragUpdateDetails details) {
    // 手指/光标向上拖（delta.dy < 0）增大输入区高度
    setState(() {
      _editorHeight = (_editorHeight - details.delta.dy).clamp(_minHeight, _maxHeight);
    });
  }

  /// 组合键发送：支持 Ctrl+Enter / Command+Enter。
  void _trySendFromShortcut() {
    if (!widget.wsConnected || widget.agentBusy) {
      return;
    }
    widget.onSendMessage(widget.inputController.text);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: GestureDetector(
              key: const ValueKey('chat-composer-resize-handle'),
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: _onResizeDragUpdate,
              child: Tooltip(
                message: '上下拖动调整输入区高度',
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: SizedBox(
                    height: _editorHeight,
                    child: CallbackShortcuts(
                      bindings: <ShortcutActivator, VoidCallback>{
                        SingleActivator(
                          LogicalKeyboardKey.enter,
                          control: true,
                        ): _trySendFromShortcut,
                        SingleActivator(
                          LogicalKeyboardKey.enter,
                          meta: true,
                        ): _trySendFromShortcut,
                      },
                      child: TextField(
                        key: const ValueKey('chat-input-field'),
                        controller: widget.inputController,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        keyboardType: TextInputType.multiline,
                        textAlignVertical: TextAlignVertical.top,
                        enabled: !widget.agentBusy,
                        decoration: InputDecoration(
                          hintText: widget.agentBusy
                              ? '正在执行...'
                              : '输入指令…（Ctrl/Command+Enter 发送）',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignLabelWithHint: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.newline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: widget.wsConnected && !widget.agentBusy
                      ? () => widget.onSendMessage(widget.inputController.text)
                      : (widget.agentBusy && widget.wsConnected
                          ? widget.onCancel
                          : null),
                  icon: Icon(widget.agentBusy ? Icons.stop : Icons.send),
                  style: widget.agentBusy
                      ? IconButton.styleFrom(
                          backgroundColor: cs.error,
                        )
                      : null,
                  tooltip: widget.agentBusy ? '停止执行' : '发送（Ctrl+Enter / Command+Enter）',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
