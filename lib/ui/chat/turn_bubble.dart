import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat_turn_models.dart';
import 'markdown_content_view.dart';

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
  void _handleCopy() {
    widget.onCopy?.call();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = widget.turn.role == TurnRole.user;
    final hasThoughts = widget.turn.thoughtSteps.isNotEmpty;
    final finalText = widget.turn.filteredFinalContent;
    final toolPreviewBytes =
        isUser ? const <Uint8List>[] : _flattenToolPreviewImages(widget.turn);
    final hasToolPreviews = toolPreviewBytes.isNotEmpty;
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
                // 操作报告（如果有）
                if (widget.turn.renderedDocument != null) ...[
                  const SizedBox(height: 8),
                  _buildExecutionReport(context, cs),
                ],
                if (hasToolPreviews) ...[
                  const SizedBox(height: 8),
                  _buildOutsideToolPreviews(context, cs, toolPreviewBytes),
                ],
                if (hasThoughts) ...[
                  const SizedBox(height: 8),
                  _buildThoughtBlock(context, cs),
                ],
                if (finalText.isNotEmpty) ...[
                  if (hasThoughts || hasToolPreviews || widget.turn.renderedDocument != null) const SizedBox(height: 8),
                  // 使用 Markdown 渲染器替代普通文本
                  MarkdownContentView(
                    markdown: finalText,
                    textColor: textColor,
                    onCopy: _handleCopy,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 收集本 turn 内所有工具步骤附带的预览图（顺序与步骤一致），供在思考区外展示。
  static List<Uint8List> _flattenToolPreviewImages(ChatTurn turn) {
    final out = <Uint8List>[];
    for (final step in turn.thoughtSteps) {
      if (step.type == StepType.toolCall && step.previewImages.isNotEmpty) {
        out.addAll(step.previewImages);
      }
    }
    return out;
  }

  /// 思考过程折叠时仍可见：工具产出的图像预览条。
  Widget _buildOutsideToolPreviews(
    BuildContext context,
    ColorScheme cs,
    List<Uint8List> images,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '图像预览',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < images.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: Material(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.memory(
                    images[i],
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '无法解码图像',
                        style: TextStyle(color: cs.error, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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
        // 移除顶部的复制按钮，因为 MarkdownContentView 已经包含了复制功能
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

  Widget _buildExecutionReport(BuildContext context, ColorScheme cs) {
    final document = widget.turn.renderedDocument!;
    final metadata = document.metadata;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('execution-report-${widget.turn.messageId}'),
        initiallyExpanded: false, // 默认折叠
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        title: Row(
          children: [
            Icon(
              metadata.success ? Icons.assessment_outlined : Icons.error_outline,
              size: 14,
              color: cs.tertiary,
            ),
            const SizedBox(width: 8),
            Text(
              metadata.title,
              style: TextStyle(
                fontSize: 11,
                color: cs.tertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${(metadata.durationMs / 1000).toStringAsFixed(1)}s',
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: MarkdownContentView(
              markdown: document.markdown,
              textColor: cs.onSurfaceVariant,
              // 不显示复制按钮，因为这是报告
              onCopy: null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(ThoughtStep step, ColorScheme cs) {
    if (step.type == StepType.thought) {
      final thoughtText = ChatTurn.stripInlineDataImageBase64(step.text ?? '');
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 14, color: cs.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                thoughtText,
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
