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
