import 'package:flutter/material.dart';
import 'package:microscope_app/ui/chat/chat_models.dart';

class SystemMessageBubble extends StatelessWidget {
  final SystemMessage message;

  const SystemMessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    IconData? icon;

    switch (message.type) {
      case SystemMessageType.info:
        backgroundColor = Colors.blue.shade50.withValues(alpha: 0.6);
        icon = Icons.info_outline;
        break;
      case SystemMessageType.success:
        backgroundColor = Colors.green.shade50.withValues(alpha: 0.6);
        icon = Icons.check_circle_outline;
        break;
      case SystemMessageType.warning:
        backgroundColor = Colors.orange.shade50.withValues(alpha: 0.6);
        icon = Icons.warning_outlined;
        break;
      case SystemMessageType.progress:
        backgroundColor = Colors.grey.shade100.withValues(alpha: 0.6);
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
            Icon(icon, size: 12, color: Colors.grey.shade700),
            const SizedBox(width: 4.0),
            Text(
              message.content,
              style: TextStyle(
                fontSize: 12.0,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
