import 'package:flutter/material.dart';
import 'package:microscope_app/ui/chat/chat_models.dart';

/// 渲染系统消息的气泡组件。
///
/// 系统消息用于显示通知、警告、进度更新等信息性内容。
/// 组件根据消息类型显示不同的颜色和图标：
/// - [SystemMessageType.info]: 蓝色背景，信息图标
/// - [SystemMessageType.success]: 绿色背景，成功图标
/// - [SystemMessageType.warning]: 橙色背景，警告图标
/// - [SystemMessageType.progress]: 灰色背景，进度图标
class SystemMessageBubble extends StatelessWidget {
  final SystemMessage message;

  const SystemMessageBubble({
    super.key,
    required this.message,
  });

  String _getSemanticLabel(SystemMessageType type) {
    switch (type) {
      case SystemMessageType.info:
        return '信息';
      case SystemMessageType.success:
        return '成功';
      case SystemMessageType.warning:
        return '警告';
      case SystemMessageType.progress:
        return '进度';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color backgroundColor;
    IconData icon;

    switch (message.type) {
      case SystemMessageType.info:
        backgroundColor = cs.primaryContainer.withValues(alpha: 0.6);
        icon = Icons.info_outline;
        break;
      case SystemMessageType.success:
        backgroundColor = cs.tertiaryContainer.withValues(alpha: 0.6);
        icon = Icons.check_circle_outline;
        break;
      case SystemMessageType.warning:
        backgroundColor = cs.errorContainer.withValues(alpha: 0.6);
        icon = Icons.warning_outlined;
        break;
      case SystemMessageType.progress:
        backgroundColor = cs.surfaceContainerHighest.withValues(alpha: 0.6);
        icon = Icons.sync_outlined;
        break;
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: Colors.grey.shade700,
              semanticLabel: _getSemanticLabel(message.type),
            ),
            const SizedBox(width: 4.0),
            Flexible(
              child: Text(
                message.content,
                style: TextStyle(
                  fontSize: 12.0,
                  color: Colors.grey.shade700,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
