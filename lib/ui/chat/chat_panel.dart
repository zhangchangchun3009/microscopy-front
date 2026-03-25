import 'package:flutter/material.dart';

import 'chat_turn_models.dart';
import 'turn_bubble.dart';

/// 右侧聊天面板组件。
///
/// 组件只负责 UI 渲染与用户交互事件分发，不持有业务状态。
class ChatPanel extends StatelessWidget {
  /// 创建聊天面板。
  ///
  /// 主要参数：
  /// - [turns] 当前对话 turn 列表（用户和助手消息）；
  /// - [inputController]/[scrollController] 由上层状态持有，确保折叠/展开后状态连续；
  /// - [plainTextMode] 控制气泡视图与纯文本视图切换；
  /// - [onSendMessage]/[onTogglePlainTextMode]/[onCopyAllMessages] 由上层注入行为。
  const ChatPanel({
    super.key,
    required this.turns,
    required this.inputController,
    required this.scrollController,
    required this.plainTextMode,
    required this.agentBusy,
    required this.wsConnected,
    required this.plainTextTranscript,
    required this.onTogglePlainTextMode,
    required this.onCopyAllMessages,
    required this.onSendMessage,
  });

  /// 对话 turn 列表。
  final List<ChatTurn> turns;

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        _buildHeader(cs),
        Expanded(
          child: turns.isEmpty
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
                  itemCount: turns.length,
                  itemBuilder: (context, i) => TurnBubble(
                    key: ValueKey('turn-${turns[i].messageId}-$i'),
                    turn: turns[i],
                  ),
                ),
        ),
        _buildComposer(cs),
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
          const Expanded(child: Text('Agent 对话')),
          if (turns.isNotEmpty) ...[
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

  /// 构建消息输入区域（文本框 + 发送按钮）
  Widget _buildComposer(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('chat-input-field'),
              controller: inputController,
              decoration: InputDecoration(
                hintText: '输入指令…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
              onSubmitted: onSendMessage,
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: wsConnected && !agentBusy
                ? () => onSendMessage(inputController.text)
                : null,
            icon: const Icon(Icons.send),
            tooltip: '发送',
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
