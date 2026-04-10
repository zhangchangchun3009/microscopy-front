/// 聊天消息角色类型。
enum MsgRole { user, assistant, toolCall, toolResult, error, status }

/// 对话消息模型。
///
/// - [role] 指示消息来源/语义类型；
/// - [text] 为渲染文本主体；
/// - [toolName]/[toolArgs] 仅在工具调用相关消息中使用。
class ChatMsg {
  /// 创建一条聊天消息。
  ///
  /// [time] 未传入时会自动填充为当前时间。
  ChatMsg({
    required this.role,
    required this.text,
    DateTime? time,
    this.toolName,
    this.toolArgs,
  }) : time = time ?? DateTime.now();

  /// 消息角色。
  final MsgRole role;

  /// 消息文本内容。
  final String text;

  /// 消息时间戳。
  final DateTime time;

  /// 工具名（仅工具调用/结果消息使用）。
  final String? toolName;

  /// 工具参数（仅工具调用消息使用）。
  final Map<String, dynamic>? toolArgs;
}

/// System message types for notifications
enum SystemMessageType {
  info,      // 一般信息
  success,   // 成功操作
  warning,   // 警告
  progress,  // 进度更新
}

/// System message embedded in conversation flow
class SystemMessage {
  /// The message content text
  final String content;

  /// When the message was created
  final DateTime time;

  /// The type/category of the system message
  final SystemMessageType type;

  /// Creates a new system message
  const SystemMessage({
    required this.content,
    required this.time,
    required this.type,
  });

  /// Creates a copy of this message with the given fields replaced
  SystemMessage copyWith({
    String? content,
    DateTime? time,
    SystemMessageType? type,
  }) {
    return SystemMessage(
      content: content ?? this.content,
      time: time ?? this.time,
      type: type ?? this.type,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SystemMessage &&
          runtimeType == other.runtimeType &&
          content == other.content &&
          time == other.time &&
          type == other.type;

  @override
  int get hashCode => content.hashCode ^ time.hashCode ^ type.hashCode;

  @override
  String toString() =>
      'SystemMessage(content: $content, time: $time, type: $type)';
}
