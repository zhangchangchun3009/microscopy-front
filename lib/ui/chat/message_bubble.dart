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
    } else {
      return _buildAssistantBubble(cs);
    }
  }

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
                  color: cs.onSurfaceVariant.withOpacity(0.7),
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
                  color: cs.onSurfaceVariant.withOpacity(0.7),
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

  String _formatTime(DateTime time) {
    return '${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}
