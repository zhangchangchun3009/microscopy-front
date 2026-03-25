import 'dart:typed_data';

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

    testWidgets('capture 预览在思考区外，折叠时仍可见 Image', (tester) async {
      final tinyPng = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]);
      final turn = ChatTurn(messageId: 'cap')
        ..startToolCall(toolName: 'capture_image')
        ..endToolCall(status: ToolStatus.success, previewImages: [tinyPng])
        ..updateContent('拍摄完成')
        ..finish();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TurnBubble(turn: turn)),
        ),
      );

      expect(find.text('图像预览'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('过滤 data:image/jpeg;base64 的内联 markdown 图片占位', (tester) async {
      final turn = ChatTurn(messageId: 'img-md')
        ..updateContent('前缀![](data:image/jpeg;base64,abcd1234)后缀')
        ..finish();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TurnBubble(turn: turn)),
        ),
      );

      expect(find.textContaining('data:image'), findsNothing);
      expect(find.textContaining('前缀后缀'), findsOneWidget);
    });

    testWidgets('思考过程的内联 data:image 占位也会过滤', (tester) async {
      final turn = ChatTurn(messageId: 'img-md-thought')
        ..addThoughtStep('思考前![](data:image/jpeg;base64,abcd1234)思考后')
        ..finish();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TurnBubble(turn: turn)),
        ),
      );

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      expect(find.textContaining('data:image'), findsNothing);
      expect(find.textContaining('思考前思考后'), findsOneWidget);
    });
  });
}
