import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat_turn_models.dart';

/// 渲染单个 [ChatTurn] 的聊天气泡。
///
/// 组件职责：
/// - 根据 [ChatTurn.role] 渲染用户/助手视觉样式；
/// - 在存在 [ChatTurn.thoughtSteps] 时提供可折叠思考区块；
/// - 对工具调用步骤显示运行状态；
/// - 支持复制最终文本（[ChatTurn.finalContent]）。
class TurnBubble extends StatefulWidget {
  /// 创建一个 turn 气泡组件。
  const TurnBubble({super.key, required this.turn, this.onCopy});

  /// 当前要渲染的 turn 数据。
  final ChatTurn turn;

  /// 复制动作回调（可选）。
  final VoidCallback? onCopy;

  @override
  State<TurnBubble> createState() => _TurnBubbleState();
}

class _TurnBubbleState extends State<TurnBubble> {
  bool _copied = false;

  Future<void> _handleCopy() async {
    widget.onCopy?.call();
    final text = widget.turn.finalContent;
    if (text.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = widget.turn.role == TurnRole.user;
    final hasThoughts = widget.turn.thoughtSteps.isNotEmpty;
    final bubbleColor = isUser ? cs.primary : cs.surfaceContainerHigh;
    final textColor = isUser ? cs.onPrimary : cs.onSurface;

    return AnimatedBuilder(
      animation: widget.turn,
      builder: (context, child) {
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            margin: EdgeInsets.only(
              bottom: 10,
              left: isUser ? 52 : 0,
              right: isUser ? 0 : 52,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, cs, isUser),
                if (hasThoughts) ...[
                  const SizedBox(height: 8),
                  _buildThoughtBlock(context, cs),
                ],
                if (widget.turn.finalContent.isNotEmpty) ...[
                  if (hasThoughts) const SizedBox(height: 8),
                  SelectableText(
                    widget.turn.finalContent,
                    style: TextStyle(color: textColor),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs, bool isUser) {
    return Row(
      children: [
        Icon(
          isUser ? Icons.person : Icons.smart_toy,
          size: 16,
          color: isUser ? cs.onPrimary : cs.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          isUser ? '我' : '助手',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isUser ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        if (widget.turn.finalContent.isNotEmpty)
          IconButton(
            tooltip: _copied ? '已复制' : '复制最终文本',
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            onPressed: _handleCopy,
            icon: Icon(
              _copied ? Icons.check : Icons.copy,
              color: isUser ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildThoughtBlock(BuildContext context, ColorScheme cs) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('thought-${widget.turn.messageId}'),
        initiallyExpanded: widget.turn.isThinkingExpanded,
        onExpansionChanged: (expanded) {
          widget.turn.isThinkingExpanded = expanded;
        },
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        title: Row(
          children: [
            Icon(
              widget.turn.isComplete ? Icons.check_circle_outline : Icons.psychology_outlined,
              size: 16,
              color: cs.tertiary,
            ),
            const SizedBox(width: 8),
            Text(
              widget.turn.isComplete ? '思考过程' : '思考中...',
              style: TextStyle(
                fontSize: 12,
                color: cs.tertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${widget.turn.thoughtSteps.length} 步',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        children: widget.turn.thoughtSteps
            .map((step) => _buildStepItem(step, cs))
            .toList(growable: false),
      ),
    );
  }

  Widget _buildStepItem(ThoughtStep step, ColorScheme cs) {
    if (step.type == StepType.thought) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 14, color: cs.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                step.text ?? '',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    final status = step.toolStatus ?? ToolStatus.running;
    final statusIcon = switch (status) {
      ToolStatus.running => const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      ToolStatus.success => const Icon(Icons.check, size: 16, color: Colors.green),
      ToolStatus.error => Icon(Icons.close, size: 16, color: cs.error),
    };
    final statusLabel = switch (status) {
      ToolStatus.running => '运行中',
      ToolStatus.success => '成功',
      ToolStatus.error => '失败',
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          statusIcon,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              step.toolName == null ? '工具调用' : '工具: ${step.toolName}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(statusLabel, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
