import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/chat/thinking_flow_widget.dart';
import 'package:microscope_app/ui/chat/chat_display_models.dart';
import 'package:microscope_app/ui/chat/chat_models.dart';

void main() {
  group('ThinkingFlowWidget', () {
    testWidgets('应该显示折叠的预览', (tester) async {
      final block = ThinkingBlock(
        messages: [
          ChatMsg(role: MsgRole.toolCall, text: '调用工具', toolName: 'search'),
        ],
        startTime: DateTime(2026, 3, 24, 10, 0),
        isExpanded: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThinkingFlowWidget(
              block: block,
              onToggleExpansion: (_) {},
              onCopy: () {},
            ),
          ),
        ),
      );

      // 预览显示工具名称，而不是完整文本
      expect(find.textContaining('search'), findsOneWidget);
    });

    testWidgets('点击应该切换展开状态', (tester) async {
      final block = ThinkingBlock(
        messages: [
          ChatMsg(role: MsgRole.toolCall, text: '测试'),
        ],
        startTime: DateTime(2026, 3, 24, 10, 0),
        isExpanded: false,
      );

      bool toggleCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThinkingFlowWidget(
              block: block,
              onToggleExpansion: (_) => toggleCalled = true,
              onCopy: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector).first);
      expect(toggleCalled, true);
    });

    testWidgets('应该显示活动状态', (tester) async {
      final activeBlock = ThinkingBlock(
        messages: [
          ChatMsg(role: MsgRole.status, text: '思考中'),
        ],
        startTime: DateTime(2026, 3, 24, 10, 0),
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThinkingFlowWidget(
              block: activeBlock,
              onToggleExpansion: (_) {},
              onCopy: () {},
            ),
          ),
        ),
      );

      expect(find.text('思考中...'), findsOneWidget);
    });

    testWidgets('应该显示非活动状态', (tester) async {
      final inactiveBlock = ThinkingBlock(
        messages: [
          ChatMsg(role: MsgRole.toolResult, text: '完成'),
        ],
        startTime: DateTime(2026, 3, 24, 10, 0),
        isActive: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThinkingFlowWidget(
              block: inactiveBlock,
              onToggleExpansion: (_) {},
              onCopy: () {},
            ),
          ),
        ),
      );

      expect(find.text('思考过程'), findsOneWidget);
    });
  });
}
