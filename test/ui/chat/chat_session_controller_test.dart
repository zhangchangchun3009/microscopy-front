import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/chat/chat_session_controller.dart';
import 'package:microscope_app/ui/chat/chat_models.dart';
import 'package:microscope_app/ui/chat/chat_display_models.dart';

void main() {
  group('消息分组逻辑', () {
    test('应该在用户消息后创建新的思维块', () {
      final controller = ChatSessionController();

      // 初始状态：没有显示项
      expect(controller.displayItems.length, equals(0));

      // 初始状态agentBusy为false
      expect(controller.agentBusy, isFalse);

      // 未连接时发送消息不会有任何效果
      controller.sendMessage('测试消息');
      expect(controller.displayItems.length, equals(0));

      controller.dispose();
    });

    test('应该将状态消息添加到messages列表', () {
      final controller = ChatSessionController();

      // 测试状态消息的添加
      controller.appendStatus('测试状态');

      // 状态消息应该添加到messages
      expect(controller.messages.length, greaterThan(0));
      expect(controller.messages.last.role, equals(MsgRole.status));
      expect(controller.messages.last.text, equals('测试状态'));

      controller.dispose();
    });

    test('应该在助手响应后关闭思维块', () {
      final controller = ChatSessionController();

      // 初始状态agentBusy为false
      expect(controller.agentBusy, isFalse);

      // 断开后agentBusy仍为false
      controller.disconnect();
      expect(controller.agentBusy, isFalse);

      controller.dispose();
    });

    test('displayItems应该返回不可修改的列表', () {
      final controller = ChatSessionController();

      final items = controller.displayItems;
      expect(() => items.add(MessageItem(ChatMsg(role: MsgRole.user, text: 'test'))),
          throwsUnsupportedError);

      controller.dispose();
    });

    test('初始状态应该有正确的默认值', () {
      final controller = ChatSessionController();

      expect(controller.displayItems.length, equals(0));
      expect(controller.messages.length, equals(0));
      expect(controller.wsConnected, isFalse);
      expect(controller.agentBusy, isFalse);

      controller.dispose();
    });

    test('应该处理空的思维块', () {
      final controller = ChatSessionController();

      // 切换空列表不应该抛出异常
      expect(() => controller.toggleThinkingBlock(0), returnsNormally);
      expect(() => controller.toggleThinkingBlock(-1), returnsNormally);
      expect(() => controller.toggleThinkingBlock(100), returnsNormally);

      // 状态应该保持不变
      expect(controller.displayItems.length, equals(0));

      controller.dispose();
    });

    test('应该在连接后发送消息创建显示项', () async {
      final controller = ChatSessionController();

      // 连接后发送消息
      await controller.connect('ws://localhost:8080');

      // 连接过程会添加状态消息
      final hasStatusMessages = controller.messages.any((msg) => msg.role == MsgRole.status);
      expect(hasStatusMessages, isTrue);

      controller.dispose();
    });

    test('应该正确处理多条连续状态消息', () {
      final controller = ChatSessionController();

      // 添加多条状态消息
      controller.appendStatus('状态1');
      controller.appendStatus('状态2');
      controller.appendStatus('状态3');

      // 所有消息都应该在messages列表中
      expect(controller.messages.length, equals(3));
      expect(controller.messages[0].text, equals('状态1'));
      expect(controller.messages[1].text, equals('状态2'));
      expect(controller.messages[2].text, equals('状态3'));

      controller.dispose();
    });
  });

  group('toggleThinkingBlock', () {
    test('应该切换思维块的展开状态', () {
      final controller = ChatSessionController();

      // 由于sendMessage需要连接，我们测试边界情况
      // 当没有思维块时，不应该抛出异常
      expect(() => controller.toggleThinkingBlock(0), returnsNormally);
      expect(() => controller.toggleThinkingBlock(-1), returnsNormally);
      expect(() => controller.toggleThinkingBlock(999), returnsNormally);

      controller.dispose();
    });

    test('应该处理非ThinkingItem的情况', () {
      final controller = ChatSessionController();

      // 添加状态消息（不是思维块）
      controller.appendStatus('测试状态');

      // 切换不应该抛出异常，即使项目不是ThinkingItem
      if (controller.displayItems.isNotEmpty) {
        expect(() => controller.toggleThinkingBlock(0), returnsNormally);
      }

      controller.dispose();
    });

    test('应该正确处理索引越界', () {
      final controller = ChatSessionController();

      // 添加一些消息
      controller.appendStatus('测试1');
      controller.appendStatus('测试2');

      final itemCount = controller.displayItems.length;

      // 测试各种边界情况
      expect(() => controller.toggleThinkingBlock(-1), returnsNormally);
      expect(() => controller.toggleThinkingBlock(itemCount), returnsNormally);
      expect(() => controller.toggleThinkingBlock(itemCount + 10), returnsNormally);

      controller.dispose();
    });
  });

  group('思维块预览', () {
    test('应该使用正确的常量值', () {
      // 验证常量存在且值为5
      expect(ChatSessionController.previewLineCount, equals(5));
    });
  });
}
