import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    testWidgets('Ctrl+Enter 触发发送，Enter 保持换行', (tester) async {
      String? sentText;
      final inputController = TextEditingController(text: '第一行');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatPanel(
              turns: const [],
              inputController: inputController,
              scrollController: ScrollController(),
              plainTextMode: false,
              agentBusy: false,
              wsConnected: true,
              plainTextTranscript: '',
              onTogglePlainTextMode: () {},
              onCopyAllMessages: () {},
              onSendMessage: (text) => sentText = text,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('chat-input-field')));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(sentText, isNull);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(sentText, '第一行');
    });

    testWidgets('Command+Enter 也可触发发送', (tester) async {
      String? sentText;
      final inputController = TextEditingController(text: 'mac 快捷键发送');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatPanel(
              turns: const [],
              inputController: inputController,
              scrollController: ScrollController(),
              plainTextMode: false,
              agentBusy: false,
              wsConnected: true,
              plainTextTranscript: '',
              onTogglePlainTextMode: () {},
              onCopyAllMessages: () {},
              onSendMessage: (text) => sentText = text,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('chat-input-field')));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(sentText, 'mac 快捷键发送');
    });
  });
}
