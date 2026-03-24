import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_display_models.dart';
import 'chat_models.dart';

/// 思维流显示组件
class ThinkingFlowWidget extends StatefulWidget {
  final ThinkingBlock block;
  final ValueChanged<bool> onToggleExpansion;
  final VoidCallback onCopy;

  const ThinkingFlowWidget({
    super.key,
    required this.block,
    required this.onToggleExpansion,
    required this.onCopy,
  });

  @override
  State<ThinkingFlowWidget> createState() => _ThinkingFlowWidgetState();
}

class _ThinkingFlowWidgetState extends State<ThinkingFlowWidget> {
  bool _showCopiedFeedback = false;

  void _handleCopy() async {
    try {
      final content = widget.block.isExpanded
          ? _buildFullText()
          : _buildPreviewText();

      await Clipboard.setData(ClipboardData(text: content));
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

  String _buildPreviewText() {
    final lines = <String>[];
    for (final msg in widget.block.messages) {
      final prefix = switch (msg.role) {
        MsgRole.toolCall => '🔧 ${msg.toolName ?? "工具"}',
        MsgRole.toolResult => '✓ ${msg.toolName ?? "结果"}',
        MsgRole.error => '❌ ${msg.text}',
        MsgRole.status => 'ℹ️ ${msg.text}',
        _ => '',
      };
      if (prefix.isNotEmpty) {
        lines.add(prefix);
      }
    }
    return lines.join('\n');
  }

  String _buildFullText() {
    final buffer = StringBuffer();
    for (final msg in widget.block.messages) {
      final prefix = switch (msg.role) {
        MsgRole.toolCall => '🔧 工具调用: ${msg.toolName ?? "?"}',
        MsgRole.toolResult => '✓ 工具结果: ${msg.toolName ?? ""}',
        MsgRole.error => '❌ 错误',
        MsgRole.status => 'ℹ️ 状态',
        _ => '',
      };
      if (prefix.isNotEmpty) {
        buffer.writeln(prefix);
        buffer.writeln(msg.text);
      }
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: cs.tertiary.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(cs),
          if (widget.block.isExpanded)
            _buildExpandedContent(cs)
          else
            _buildPreview(cs),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return GestureDetector(
      onTap: () => widget.onToggleExpansion(!widget.block.isExpanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Icon(
              widget.block.isActive
                  ? Icons.psychology_outlined
                  : Icons.check_circle_outline,
              size: 16,
              color: cs.tertiary,
            ),
            const SizedBox(width: 8),
            Text(
              widget.block.isActive ? '思考中...' : '思考过程',
              style: TextStyle(
                fontSize: 12,
                color: cs.tertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            _buildCopyButton(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(ColorScheme cs) {
    return GestureDetector(
      onTap: () => widget.onToggleExpansion(!widget.block.isExpanded),
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(minHeight: 80),
        child: SelectableText(
          _buildPreviewText(),
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant,
            fontFamily: 'monospace',
          ),
          maxLines: 5,
        ),
      ),
    );
  }

  Widget _buildExpandedContent(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.block.messages.map((msg) => _buildMessageItem(msg, cs)).toList(),
      ),
    );
  }

  Widget _buildMessageItem(ChatMsg msg, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            switch (msg.role) {
              MsgRole.toolCall => Icons.build,
              MsgRole.toolResult => Icons.check_circle,
              MsgRole.error => Icons.error,
              MsgRole.status => Icons.info,
              _ => Icons.circle,
            },
            size: 14,
            color: cs.tertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              msg.text,
              style: const TextStyle(fontSize: 12),
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
}
