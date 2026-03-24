// lib/ui/chat/chat_display_models.dart
import 'chat_models.dart';

/// 思维块 - 包含所有中间消息（工具调用、结果、错误等）
class ThinkingBlock {
  /// 块中的所有消息
  final List<ChatMsg> messages;

  /// 思维开始时间
  final DateTime startTime;

  /// 是否展开
  bool isExpanded;

  /// 是否正在进行中
  bool isActive;

  ThinkingBlock({
    required this.messages,
    required this.startTime,
    this.isExpanded = false,
    this.isActive = true,
  });

  /// 添加消息到块中
  void addMessage(ChatMsg msg) {
    messages.add(msg);
  }
}

/// 聊天显示项的联合类型
sealed class ChatDisplayItem {}

/// 单条消息项
class MessageItem extends ChatDisplayItem {
  final ChatMsg message;
  MessageItem(this.message);
}

/// 思维块项
class ThinkingItem extends ChatDisplayItem {
  final ThinkingBlock block;
  ThinkingItem(this.block);
}