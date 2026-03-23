import 'dart:convert';

import 'package:flutter/material.dart';

import 'chat_models.dart';

/// Formats message timestamp as "MM-dd HH:mm".
String _formatMessageTime(DateTime time) {
  return '${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')} '
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

/// 右侧聊天面板组件。
///
/// 组件只负责 UI 渲染与用户交互事件分发，不持有业务状态。
class ChatPanel extends StatelessWidget {
  /// 创建聊天面板。
  ///
  /// 主要参数：
  /// - [messages] 当前对话消息列表；
  /// - [inputController]/[scrollController] 由上层状态持有，确保折叠/展开后状态连续；
  /// - [plainTextMode] 控制气泡视图与纯文本视图切换；
  /// - [onSendMessage]/[onTogglePlainTextMode]/[onCopyAllMessages] 由上层注入行为。
  const ChatPanel({
    super.key,
    required this.messages,
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

  /// 对话消息列表。
  final List<ChatMsg> messages;

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
          child: messages.isEmpty
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
                  itemCount: messages.length,
                  itemBuilder: (_, i) => _buildMessage(messages[i], cs),
                ),
        ),
        _buildComposer(cs),
      ],
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: cs.surfaceContainerHighest,
      child: Row(
        children: [
          const Icon(Icons.chat, size: 18),
          const SizedBox(width: 8),
          const Expanded(child: Text('Agent 对话')),
          if (messages.isNotEmpty) ...[
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

  Widget _buildMessage(ChatMsg msg, ColorScheme cs) {
    return switch (msg.role) {
      MsgRole.user => _userBubble(msg, cs),
      MsgRole.assistant => _assistantBubble(msg, cs),
      MsgRole.toolCall => _toolCallCard(msg, cs),
      MsgRole.toolResult => _toolResultCard(msg, cs),
      MsgRole.error => _errorCard(msg, cs),
      MsgRole.status => _statusLine(msg, cs),
    };
  }

  Widget _userBubble(ChatMsg msg, ColorScheme cs) {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header on the right (mirrored)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '@${_formatMessageTime(msg.time)}',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '我',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.person, size: 16, color: cs.primary),
            ],
          ),
          const SizedBox(height: 4),
          // Bubble
          Container(
            constraints: const BoxConstraints(maxWidth: 500),
            margin: const EdgeInsets.only(bottom: 8, left: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary.withValues(
                alpha: 0.85,
              ), // Lighter for text selection visibility
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(
              msg.text,
              style: TextStyle(color: cs.onPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _assistantBubble(ChatMsg msg, ColorScheme cs) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header on the left
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smart_toy, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                '助手',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '@${_formatMessageTime(msg.time)}',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Bubble
          Container(
            constraints: const BoxConstraints(maxWidth: 500),
            margin: const EdgeInsets.only(bottom: 8, right: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(msg.text),
          ),
        ],
      ),
    );
  }

  Widget _toolCallCard(ChatMsg msg, ColorScheme cs) {
    final argsStr = msg.toolArgs != null
        ? const JsonEncoder.withIndent('  ').convert(msg.toolArgs)
        : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: cs.tertiary.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        dense: true,
        leading: Icon(Icons.build, size: 18, color: cs.tertiary),
        title: SelectableText(
          '工具调用: ${msg.toolName ?? "?"}',
          style: TextStyle(fontSize: 13, color: cs.tertiary),
        ),
        children: [
          if (argsStr.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: cs.surfaceContainerHighest,
              child: SelectableText(
                argsStr,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolResultCard(ChatMsg msg, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: cs.secondary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        dense: true,
        initiallyExpanded: false,
        leading: Icon(
          Icons.check_circle_outline,
          size: 18,
          color: cs.secondary,
        ),
        title: SelectableText(
          '工具结果: ${msg.toolName ?? ""}',
          style: TextStyle(fontSize: 13, color: cs.secondary),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: cs.surfaceContainerHighest,
            child: SelectableText(
              msg.text,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(ChatMsg msg, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: cs.error),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              msg.text,
              style: TextStyle(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusLine(ChatMsg msg, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: SelectableText(
          msg.text,
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
