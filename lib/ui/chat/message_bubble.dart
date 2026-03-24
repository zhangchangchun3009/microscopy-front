import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_models.dart';

/// 可复用的消息气泡组件
class MessageBubble extends StatefulWidget {
  final ChatMsg message;
  final VoidCallback onCopy;

  const MessageBubble({
    super.key,
    required this.message,
    required this.onCopy,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _showCopiedFeedback = false;

  void _handleCopy() async {
    widget.onCopy();
    try {
      await Clipboard.setData(ClipboardData(text: widget.message.text));
      setState(() => _showCopiedFeedback = true);
      Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _showCopiedFeedback = false);
        }
      });
    } catch (_) {
      // 静默失败
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (widget.message.role == MsgRole.user) {
      return _buildUserBubble(cs);
    } else if (widget.message.role == MsgRole.assistant) {
      return _buildAssistantBubble(cs);
    } else if (widget.message.role == MsgRole.status) {
      return _buildStatusLine(cs);
    } else {
      // For other message types (toolCall, toolResult, error), show as simple cards
      return _buildSimpleCard(cs);
    }
  }

  /// 构建用户消息气泡（右侧对齐，蓝色背景）
  Widget _buildUserBubble(ColorScheme cs) {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(widget.message.time),
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
          Container(
            constraints: const BoxConstraints(maxWidth: 500),
            margin: const EdgeInsets.only(bottom: 8, left: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SelectableText(
                    widget.message.text,
                    style: TextStyle(color: cs.onPrimary),
                  ),
                ),
                _buildCopyButton(cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建助手消息气泡（左侧对齐，灰色背景）
  Widget _buildAssistantBubble(ColorScheme cs) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
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
                _formatTime(widget.message.time),
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxWidth: 500),
            margin: const EdgeInsets.only(bottom: 8, right: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SelectableText(widget.message.text),
                ),
                _buildCopyButton(cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建复制按钮，带复制反馈提示
  Widget _buildCopyButton(ColorScheme cs) {
    return Tooltip(
      message: _showCopiedFeedback ? '已复制!' : '复制',
      waitDuration: Duration.zero,
      child: IconButton(
        icon: const Icon(Icons.copy, size: 16),
        onPressed: _handleCopy,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(),
      ),
    );
  }

  /// 格式化消息时间戳为 MM-DD HH:MM 格式
  String _formatTime(DateTime time) {
    return '${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  /// 构建状态消息行（居中，小字，灰色）
  Widget _buildStatusLine(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: SelectableText(
          widget.message.text,
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  /// 构建简单卡片（工具调用、结果、错误等消息）
  Widget _buildSimpleCard(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.message.role == MsgRole.error
            ? cs.errorContainer
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            widget.message.role == MsgRole.error
                ? Icons.error_outline
                : Icons.info_outline,
            size: 18,
            color: widget.message.role == MsgRole.error
                ? cs.error
                : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              widget.message.text,
              style: TextStyle(
                color: widget.message.role == MsgRole.error
                    ? cs.onErrorContainer
                    : cs.onSurface,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
