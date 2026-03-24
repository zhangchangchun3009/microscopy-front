import 'dart:convert';

import 'chat_models.dart';

/// 协议事件映射结果。
///
/// - [messages] 为需要追加到展示层的消息列表；
/// - [agentBusy] 为事件处理后的忙闲状态。
class ChatProtocolApplyResult {
  /// 创建协议映射结果对象。
  const ChatProtocolApplyResult({
    required this.messages,
    required this.agentBusy,
  });

  /// 需要追加的展示消息。
  final List<ChatMsg> messages;

  /// Agent 忙闲状态。
  final bool agentBusy;
}

/// 将网关协议事件映射为展示消息与状态。
class ChatProtocolMapper {
  /// 处理一条协议事件。
  ///
  /// [raw] 为单条 WebSocket 字符串消息；
  /// [chunkBuffer] 为增量文本累积缓冲区；
  /// [agentBusy] 为处理前的忙闲状态；
  /// [lastMessageRole] 用于保持 `done/full_response` 与现有行为一致。
  static ChatProtocolApplyResult applyEvent({
    required String raw,
    required StringBuffer chunkBuffer,
    required bool agentBusy,
    required MsgRole? lastMessageRole,
  }) {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return ChatProtocolApplyResult(messages: const [], agentBusy: agentBusy);
    }

    final mappedMessages = <ChatMsg>[];
    final type = data['type'] as String? ?? '';
    var nextBusy = agentBusy;

    void flushChunks() {
      if (chunkBuffer.isNotEmpty) {
        mappedMessages.add(
          ChatMsg(role: MsgRole.assistant, text: chunkBuffer.toString()),
        );
        chunkBuffer.clear();
      }
    }

    switch (type) {
      case 'chunk':
        final content = data['content'] ?? '';
        chunkBuffer.write(content);

        // 通过文本模式识别特殊消息类型
        final categorized = _categorizeMessageByPattern(content);
        if (categorized != null) {
          mappedMessages.add(categorized);
        }
        break;
      case 'tool_call':
        flushChunks();
        mappedMessages.add(
          ChatMsg(
            role: MsgRole.toolCall,
            text: '调用工具: ${data['name']}',
            toolName: data['name'] as String?,
            toolArgs: data['args'] as Map<String, dynamic>?,
          ),
        );
        break;
      case 'tool_result':
        final output = data['output'] ?? data['result'] ?? '';
        mappedMessages.add(
          ChatMsg(
            role: MsgRole.toolResult,
            text: output is String ? output : jsonEncode(output),
            toolName: data['name'] as String?,
          ),
        );
        break;
      case 'done':
        flushChunks();
        final fullResponse = data['full_response'] as String?;
        if (fullResponse != null &&
            fullResponse.isNotEmpty &&
            lastMessageRole != MsgRole.assistant) {
          mappedMessages.add(
            ChatMsg(role: MsgRole.assistant, text: fullResponse),
          );
        }
        nextBusy = false;
        break;
      case 'error':
        flushChunks();
        mappedMessages.add(
          ChatMsg(role: MsgRole.error, text: data['message'] ?? '未知错误'),
        );
        nextBusy = false;
        break;
      case 'agent_start':
        nextBusy = true;
        break;
      case 'agent_end':
        nextBusy = false;
        break;
    }

    return ChatProtocolApplyResult(
      messages: mappedMessages,
      agentBusy: nextBusy,
    );
  }

  /// 通过文本模式识别特殊消息类型（用于服务器未标记类型的场景）
  static ChatMsg? _categorizeMessageByPattern(String text) {
    // 思考状态
    if (text.contains('🤔 Thinking') || text.contains('🤔')) {
      return ChatMsg(role: MsgRole.status, text: text);
    }

    // 工具调用开始
    if (text.startsWith('⏳')) {
      // 提取工具名称和参数
      final parts = text.substring(2).trim().split(':');
      final toolName = parts.isNotEmpty ? parts[0].trim() : '';
      return ChatMsg(
        role: MsgRole.toolCall,
        text: text,
        toolName: toolName.isNotEmpty ? toolName : null,
      );
    }

    // 工具调用完成
    if (text.startsWith('✓') || text.startsWith('✅')) {
      final parts = text.substring(1).trim().split(' ');
      final toolName = parts.isNotEmpty ? parts[0].trim() : '';
      return ChatMsg(
        role: MsgRole.toolResult,
        text: text,
        toolName: toolName.isNotEmpty ? toolName : null,
      );
    }

    // 工具调用统计
    if (text.contains('Got') && text.contains('tool call(s)')) {
      return ChatMsg(role: MsgRole.status, text: text);
    }

    // 默认返回 null，让消息保持原有类型
    return null;
  }
}
