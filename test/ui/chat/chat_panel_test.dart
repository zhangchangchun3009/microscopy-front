import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/chat/chat_panel.dart';
import 'package:microscope_app/ui/chat/chat_turn_models.dart';

void main() {
  group('ChatPanel with turns', () {
    testWidgets('displays assistant turn with robot icon', (tester) async {
      final assistantTurn = ChatTurn(messageId: 'a1', role: TurnRole.assistant)
        ..updateContent('Hello')
        ..finish();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatPanel(
              turns: [assistantTurn],
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

      expect(find.byIcon(Icons.smart_toy), findsOneWidget);
      expect(find.text('助手'), findsOneWidget);
    });

    testWidgets('displays user turn with person icon', (tester) async {
      final userTurn = ChatTurn(messageId: 'u1', role: TurnRole.user)
        ..updateContent('Hi')
        ..finish();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatPanel(
              turns: [userTurn],
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

      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.text('我'), findsOneWidget);
    });

    testWidgets('输入区提供可拖动调整高度的手柄', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatPanel(
              turns: const [],
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

      expect(find.byKey(const ValueKey('chat-composer-resize-handle')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-input-field')), findsOneWidget);
    });
  });
}
