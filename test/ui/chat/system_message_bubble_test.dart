import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/chat/chat_models.dart';
import 'package:microscope_app/ui/chat/system_message_bubble.dart';

IconData getExpectedIcon(SystemMessageType type) {
  switch (type) {
    case SystemMessageType.info:
      return Icons.info_outline;
    case SystemMessageType.success:
      return Icons.check_circle_outline;
    case SystemMessageType.warning:
      return Icons.warning_outlined;
    case SystemMessageType.progress:
      return Icons.sync_outlined;
  }
}

void main() {
  group('SystemMessageBubble', () {
    testWidgets('should display system message content', (tester) async {
      final message = SystemMessage(
        content: 'Test message',
        time: DateTime.now(),
        type: SystemMessageType.info,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SystemMessageBubble(message: message),
          ),
        ),
      );

      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('should show different icons for different types', (tester) async {
      final types = [
        SystemMessageType.info,
        SystemMessageType.success,
        SystemMessageType.warning,
        SystemMessageType.progress,
      ];

      for (final type in types) {
        final message = SystemMessage(
          content: 'Test',
          time: DateTime.now(),
          type: type,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SystemMessageBubble(message: message),
            ),
          ),
        );

        expect(find.byIcon(getExpectedIcon(type)), findsOneWidget);
      }
    });
  });
}
