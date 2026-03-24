import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/chat/message_bubble.dart';
import 'package:microscope_app/ui/chat/chat_models.dart';

void main() {
  group('MessageBubble', () {
    testWidgets('应该显示用户消息', (tester) async {
      final msg = ChatMsg(role: MsgRole.user, text: '测试消息');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: msg,
              onCopy: () {},
            ),
          ),
        ),
      );

      expect(find.text('测试消息'), findsOneWidget);
    });

    testWidgets('应该显示复制按钮', (tester) async {
      final msg = ChatMsg(role: MsgRole.user, text: '测试');
      bool copyCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: msg,
              onCopy: () => copyCalled = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('点击复制按钮应该触发回调', (tester) async {
      final msg = ChatMsg(role: MsgRole.user, text: '测试');
      bool copyCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: msg,
              onCopy: () => copyCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(copyCalled, true);
    });
  });
}
