import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/chat/chat_models.dart';
import 'package:microscope_app/ui/chat/chat_panel.dart';

void main() {
  group('ChatPanel with message headers', () {
    testWidgets('displays assistant message with robot icon and timestamp', (
      tester,
    ) async {
      // Arrange
      final messages = [
        ChatMsg(
          role: MsgRole.assistant,
          text: 'Hello',
          time: DateTime(2026, 3, 23, 14, 30),
        ),
      ];

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatPanel(
              messages: messages,
              inputController: TextEditingController(),
              scrollController: ScrollController(),
              plainTextMode: false,
              agentBusy: false,
              wsConnected: true,
              plainTextTranscript: '',
              onTogglePlainTextMode: () {},
              onCopyAllMessages: () {},
              onSendMessage: (_) {},
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.smart_toy), findsOneWidget);
      expect(find.text('助手'), findsOneWidget);
      // Time format check (contains colon)
      expect(find.textContaining(':'), findsWidgets);
    });

    testWidgets('displays user message with person icon and timestamp', (
      tester,
    ) async {
      // Arrange
      final messages = [
        ChatMsg(
          role: MsgRole.user,
          text: 'Hi',
          time: DateTime(2026, 3, 23, 15, 45),
        ),
      ];

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatPanel(
              messages: messages,
              inputController: TextEditingController(),
              scrollController: ScrollController(),
              plainTextMode: false,
              agentBusy: false,
              wsConnected: true,
              plainTextTranscript: '',
              onTogglePlainTextMode: () {},
              onCopyAllMessages: () {},
              onSendMessage: (_) {},
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.text('我'), findsOneWidget);
      // Time format check (contains colon)
      expect(find.textContaining(':'), findsWidgets);
    });
  });
}
