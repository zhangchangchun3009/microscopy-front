import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'chat_models.dart';
import 'chat_turn_models.dart';

/// 聊天会话控制器，封装连接生命周期、消息收发与协议解析。
///
/// 该控制器不直接依赖 Widget 树，通过 [ChangeNotifier] 向外暴露状态变更。
class ChatSessionController extends ChangeNotifier {
  // 替换原有的消息列表
  final Map<String, ChatTurn> _turns = {};
  final List<ChatTurn> _turnList = []; // 保持插入顺序

  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;

  bool _wsConnected = false;
  String? _currentTurnId; // 当前正在处理的回合 ID

  /// 当前对话回合列表（只读视图）。
  List<ChatTurn> get turns => List.unmodifiable(_turnList);

  /// WebSocket 是否已连接。
  bool get wsConnected => _wsConnected;

  /// @deprecated 使用 turns 代替。保留用于向后兼容。
  List<ChatMsg> get messages {
    // 将 ChatTurn 转换为 ChatMsg 以保持向后兼容
    return _turnList.map((turn) {
      if (turn.role == 'user') {
        return ChatMsg(role: MsgRole.user, text: turn.finalContent);
      } else if (turn.role == 'system') {
        return ChatMsg(role: MsgRole.status, text: turn.finalContent);
      } else {
        // assistant turns - 合并思考步骤和最终内容
        final parts = <String>[];
        for (final step in turn.thoughtSteps) {
          if (step.type == StepType.text) {
            parts.add(step.content);
          } else if (step.type == StepType.tool) {
            if (step.status == ToolStatus.running) {
              parts.add('[调用工具: ${step.toolName}]');
            } else if (step.status == ToolStatus.success) {
              parts.add('[工具完成: ${step.toolName}]');
            } else if (step.status == ToolStatus.error) {
              parts.add('[工具失败: ${step.toolName}]');
            }
          }
        }
        if (turn.finalContent.isNotEmpty) {
          parts.add(turn.finalContent);
        }
        return ChatMsg(role: MsgRole.assistant, text: parts.join('\n\n'));
      }
    }).toList();
  }

  /// @deprecated 不再需要。保留用于向后兼容。
  bool get agentBusy => _currentTurnId != null;

  /// 建立到给定 [url] 的 WebSocket 连接。
  ///
  /// 会先断开旧连接，再尝试连接新地址，并按现有行为写入状态消息。
  Future<void> connect(String url) async {
    disconnect();
    _appendStatus('正在连接 $url …');
    try {
      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _wsSub = _channel!.stream.listen(
        _onWsMessage,
        onError: (e) {
          _wsConnected = false;
          _currentTurnId = null;
          _appendStatus('WebSocket 错误: $e');
          notifyListeners();
        },
        onDone: () {
          _wsConnected = false;
          _currentTurnId = null;
          _appendStatus('WebSocket 已断开');
          notifyListeners();
        },
      );
      _wsConnected = true;
      _appendStatus('已连接 $url');
      notifyListeners();
    } catch (e) {
      _channel = null;
      _wsConnected = false;
      _appendStatus('连接失败: $e');
      notifyListeners();
    }
  }

  /// 断开当前连接并清理订阅资源。
  void disconnect() {
    _wsSub?.cancel();
    _wsSub = null;
    _channel?.sink.close();
    _channel = null;
    _wsConnected = false;
    _currentTurnId = null;

    // 标记所有进行中的回合为完成
    for (final turn in _turns.values) {
      if (!turn.isComplete) {
        turn.isComplete = true;
      }
    }

    notifyListeners();
  }

  /// 发送用户消息。
  ///
  /// - 若 [text] 为空或未连接，直接忽略；
  /// - 成功发送后会追加一条用户消息。
  void sendMessage(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty || !_wsConnected) {
      return;
    }

    // 用户消息不经过 WebSocket 传输，直接添加到列表
    final userTurn = ChatTurn(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
    );
    userTurn.finalContent = normalized;
    userTurn.isComplete = true;
    _turns[userTurn.id] = userTurn;
    _turnList.add(userTurn);

    _channel?.sink.add(jsonEncode({'type': 'message', 'content': normalized}));
    notifyListeners();
  }

  /// 追加状态消息，用于外部流程（如设置变更后的提示）。
  void appendStatus(String msg) {
    _appendStatus(msg);
    notifyListeners();
  }

  /// 将全部消息格式化为可复制文本。
  String formatMessagesForCopy() {
    final sb = StringBuffer();
    for (final turn in _turnList) {
      final prefix = turn.role == 'user' ? '[用户]' : '[助手]';
      sb.writeln('$prefix ${turn.finalContent}');

      // 如果有思考步骤，也包含在复制内容中
      if (turn.thoughtSteps.isNotEmpty) {
        sb.writeln('[思考过程]');
        for (final step in turn.thoughtSteps) {
          if (step.type == StepType.text) {
            sb.writeln('  - ${step.content}');
          } else {
            sb.writeln('  - 工具: ${step.toolName}');
            if (step.toolResult != null) {
              sb.writeln('    结果: ${step.toolResult}');
            }
          }
        }
      }
    }
    return sb.toString();
  }

  void _onWsMessage(dynamic raw) {
    if (raw is! String) return;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final msgId = data['message_id'] as String?;
      final type = data['type'] as String?;

      if (msgId == null || type == null) return;

      switch (type) {
        case 'turn_start':
          _handleTurnStart(msgId, data['role'] as String? ?? 'assistant');
          break;
        case 'thought_update':
          _handleThoughtUpdate(msgId, data['content'] as String? ?? '');
          break;
        case 'tool_call_start':
          _handleToolCallStart(
            msgId,
            data['step_id'] as String,
            data['tool_name'] as String,
            data['args'] as Map<String, dynamic>?,
          );
          break;
        case 'tool_call_end':
          _handleToolCallEnd(
            msgId,
            data['step_id'] as String,
            data['duration_ms'] as int,
            data['result'] as String? ?? '',
            data['success'] as bool? ?? true,
          );
          break;
        case 'content_update':
          _handleContentUpdate(msgId, data['content'] as String? ?? '');
          break;
        case 'turn_end':
          _handleTurnEnd(msgId);
          break;
      }

      notifyListeners();
    } catch (e, stack) {
      debugPrint('Error processing WebSocket message: $e');
      debugPrint(stack.toString());
    }
  }

  void _handleTurnStart(String msgId, String role) {
    final turn = ChatTurn(id: msgId, role: role);
    _turns[msgId] = turn;
    _turnList.add(turn);
    _currentTurnId = msgId;
  }

  void _handleThoughtUpdate(String msgId, String content) {
    if (!_turns.containsKey(msgId)) {
      debugPrint('Warning: received event for unknown turn: $msgId');
      _handleTurnStart(msgId, 'assistant');
    }
    _turns[msgId]?.addThoughtText(content);
  }

  void _handleToolCallStart(
    String msgId,
    String stepId,
    String toolName,
    Map<String, dynamic>? args,
  ) {
    if (!_turns.containsKey(msgId)) {
      debugPrint('Warning: received event for unknown turn: $msgId');
      _handleTurnStart(msgId, 'assistant');
    }
    _turns[msgId]?.startToolCall(stepId, toolName, args);
  }

  void _handleToolCallEnd(
    String msgId,
    String stepId,
    int duration,
    String result,
    bool success,
  ) {
    if (!_turns.containsKey(msgId)) {
      debugPrint('Warning: received event for unknown turn: $msgId');
      return;
    }
    if (success) {
      _turns[msgId]?.endToolCall(stepId, duration, result);
    } else {
      _turns[msgId]?.endToolCallWithError(stepId, duration, result);
    }
  }

  void _handleContentUpdate(String msgId, String content) {
    if (!_turns.containsKey(msgId)) {
      debugPrint('Warning: received event for unknown turn: $msgId');
      _handleTurnStart(msgId, 'assistant');
    }
    _turns[msgId]?.appendContent(content);
  }

  void _handleTurnEnd(String msgId) {
    if (!_turns.containsKey(msgId)) {
      debugPrint('Warning: received turn_end for unknown turn: $msgId');
      return;
    }
    _turns[msgId]?.finish();
    _currentTurnId = null;
  }

  void _appendStatus(String msg) {
    final statusTurn = ChatTurn(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'system',
    );
    statusTurn.finalContent = msg;
    statusTurn.isComplete = true;
    _turns[statusTurn.id] = statusTurn;
    _turnList.add(statusTurn);
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  /// Testing helper: expose _onWsMessage for unit tests.
  /// This allows simulating WebSocket events without a real connection.
  void testOnWsMessage(dynamic raw) => _onWsMessage(raw);
}
