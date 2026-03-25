import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/chat/chat_turn_models.dart';
import 'package:microscope_app/ui/chat/turn_bubble.dart';

void main() {
  group('TurnBubble', () {
    testWidgets('渲染助手气泡和思考步骤摘要', (tester) async {
      final turn = ChatTurn(messageId: 'a1', role: TurnRole.assistant)
        ..addThoughtStep('分析请求')
        ..startToolCall(toolName: 'search')
        ..updateContent('处理完成')
        ..finish();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TurnBubble(turn: turn)),
        ),
      );

      expect(find.text('助手'), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy), findsOneWidget);
      expect(find.text('2 步'), findsOneWidget);
      expect(find.text('处理完成'), findsOneWidget);
    });

    testWidgets('展开后显示工具状态文本', (tester) async {
      final turn = ChatTurn(messageId: 'a2')
        ..startToolCall(toolName: 'planner')
        ..endToolCall(status: ToolStatus.success, resultText: 'ok')
        ..finish();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TurnBubble(turn: turn)),
        ),
      );

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      expect(find.textContaining('工具: planner'), findsOneWidget);
      expect(find.text('成功'), findsOneWidget);
    });
  });
}
