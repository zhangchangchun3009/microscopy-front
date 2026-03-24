import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_turn_models.dart';

class TurnBubble extends StatefulWidget {
  final ChatTurn turn;
  final VoidCallback onCopy;

  const TurnBubble({
    super.key,
    required this.turn,
    required this.onCopy,
  });

  @override
  State<TurnBubble> createState() => _TurnBubbleState();
}

class _TurnBubbleState extends State<TurnBubble> {
  bool _showCopiedFeedback = false;

  void _handleCopy() async {
    widget.onCopy();
    try {
      await Clipboard.setData(ClipboardData(text: widget.turn.finalContent));
      setState(() => _showCopiedFeedback = true);
      Future.delayed(const Duration(milliseconds: 1500), () {
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

    return AnimatedBuilder(
      animation: widget.turn,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.turn.role == 'user'
                ? cs.primary
                : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: widget.turn.thoughtSteps.isNotEmpty &&
                    !widget.turn.isComplete
                ? Border.all(
                    color: cs.primary.withValues(alpha: 0.5),
                    width: 2,
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 思考过程区块（如果有）
              if (widget.turn.thoughtSteps.isNotEmpty)
                _buildThinkingBlock(cs),

              // 2. 最终回复内容（如果有）
              if (widget.turn.finalContent.isNotEmpty) ...[
                if (widget.turn.thoughtSteps.isNotEmpty)
                  const Divider(height: 16),
                SelectableText(
                  widget.turn.finalContent,
                  style: TextStyle(
                    color: widget.turn.role == 'user'
                        ? cs.onPrimary
                        : cs.onSurface,
                    fontSize: 15,
                  ),
                ),
              ],

              // 3. 加载指示器（如果还在进行中）
              if (!widget.turn.isComplete &&
                  widget.turn.finalContent.isEmpty &&
                  widget.turn.thoughtSteps.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThinkingBlock(ColorScheme cs) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: false, // 始终折叠
        tilePadding: EdgeInsets.zero,
        title: Row(
          children: [
            Icon(
              !widget.turn.isComplete
                  ? Icons.psychology_outlined
                  : Icons.check_circle_outline,
              color: cs.tertiary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              !widget.turn.isComplete ? '思考中...' : '思考过程',
              style: TextStyle(
                fontSize: 12,
                color: cs.tertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${widget.turn.thoughtSteps.length} 步',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        children: widget.turn.thoughtSteps
            .map((step) => _buildStepItem(step, cs))
            .toList(),
      ),
    );
  }

  Widget _buildStepItem(ThoughtStep step, ColorScheme cs) {
    if (step.type == StepType.text) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: cs.tertiary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                step.content,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // 工具调用
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            if (step.status == ToolStatus.running)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (step.status == ToolStatus.success)
              Icon(Icons.check, color: Colors.green, size: 16),
            if (step.status == ToolStatus.error)
              Icon(Icons.close, color: cs.error, size: 16),
            const SizedBox(width: 8),
            Text(
              step.toolName ?? '未知工具',
              style: const TextStyle(fontSize: 13),
            ),
            if (step.durationMs != null) ...[
              const Spacer(),
              Text(
                '${step.durationMs}ms',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      );
    }
  }
}
