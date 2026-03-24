// test/ui/chat/chat_display_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/chat/chat_display_models.dart';
import 'package:microscope_app/ui/chat/chat_models.dart';

void main() {
  group('ThinkingBlock', () {
    test('应该创建空的思维块', () {
      final block = ThinkingBlock(
        messages: [],
        startTime: DateTime.now(),
      );
      expect(block.messages, isEmpty);
      expect(block.isExpanded, false);
      expect(block.isActive, true);
    });

    test('应该支持展开状态切换', () {
      final block = ThinkingBlock(
        messages: [],
        startTime: DateTime.now(),
      );
      block.isExpanded = true;
      expect(block.isExpanded, true);
    });

    test('应该支持活动状态切换', () {
      final block = ThinkingBlock(
        messages: [],
        startTime: DateTime.now(),
      );
      block.isActive = false;
      expect(block.isActive, false);
    });

    test('应该向块添加消息', () {
      final block = ThinkingBlock(
        messages: [],
        startTime: DateTime.now(),
      );
      final msg = ChatMsg(role: MsgRole.user, text: '测试');
      block.addMessage(msg);
      expect(block.messages, [msg]);
    });
  });

  group('MessageItem', () {
    test('应该包装单条消息', () {
      final msg = ChatMsg(role: MsgRole.user, text: '测试');
      final item = MessageItem(msg);
      expect(item.message, msg);
    });
  });

  group('ThinkingItem', () {
    test('应该包装思维块', () {
      final block = ThinkingBlock(
        messages: [],
        startTime: DateTime.now(),
      );
      final item = ThinkingItem(block);
      expect(item.block, block);
    });
  });
}