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
  /// 思维块预览文本的最大行数
  static const int previewLineCount = 5;

  final List<ChatMsg> _messages = [];
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  final Map<String, ChatTurn> _turnByMessageId = {};
  final List<ChatTurn> _turns = [];

  bool _wsConnected = false;
  bool _agentBusy = false;
  // 调试开关：仅在 Debug 模式输出 WS 原始/解析日志，便于协议联调排查。
  final bool _enableWsDebugLog = kDebugMode;
  bool _protocolMismatchWarned = false;

  /// 当前消息列表（只读视图）。
  List<ChatMsg> get messages => List.unmodifiable(_messages);

  /// 以 message_id 索引的 turn 聚合结果（只读视图）。
  Map<String, ChatTurn> get turnByMessageId => Map.unmodifiable(_turnByMessageId);

  /// turn 时间序列表（只读视图）。
  List<ChatTurn> get turns => List.unmodifiable(_turns);

  /// WebSocket 是否已连接。
  bool get wsConnected => _wsConnected;

  /// Agent 是否处于处理中。
  bool get agentBusy => _agentBusy;

  /// 建立到给定 [url] 的 WebSocket 连接。
  ///
  /// 会先断开旧连接，再尝试连接新地址，并按现有行为写入状态消息。
  Future<void> connect(String url) async {
    disconnect();
    _protocolMismatchWarned = false;
    _appendStatus('正在连接 $url …');
    try {
      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _wsSub = _channel!.stream.listen(
        _onWsMessage,
        onError: (e) {
          _wsConnected = false;
          _agentBusy = false;
          _appendStatus('WebSocket 错误: $e');
          notifyListeners();
        },
        onDone: () {
          _wsConnected = false;
          _agentBusy = false;
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
    _agentBusy = false;
    _protocolMismatchWarned = false;
    notifyListeners();
  }

  /// 发送用户消息。
  ///
  /// - 若 [text] 为空或未连接，直接忽略；
  /// - 成功发送后会追加一条用户消息并将 [agentBusy] 置为 `true`。
  void sendMessage(String text, {Map<String, dynamic>? roiNorm}) {
    final normalized = text.trim();
    if (normalized.isEmpty || !_wsConnected) {
      return;
    }
    // 兼容旧逻辑：保留消息列表，同时写入用户 turn 供新 UI 渲染。
    _messages.add(ChatMsg(role: MsgRole.user, text: normalized));
    final userTurn = ChatTurn(
      messageId: 'user-${DateTime.now().microsecondsSinceEpoch}',
      role: TurnRole.user,
    );
    userTurn.updateContent(normalized);
    userTurn.finish();
    _turns.add(userTurn);

    _agentBusy = true;
    final payload = _buildOutboundMessagePayload(normalized, roiNorm: roiNorm);
    _channel?.sink.add(jsonEncode(payload));
    notifyListeners();
  }

  /// 仅供测试：构建用户消息的 WebSocket 负载。
  @visibleForTesting
  static Map<String, dynamic> buildOutboundMessagePayloadForTest(
    String content, {
    Map<String, dynamic>? roiNorm,
  }) {
    return _buildOutboundMessagePayload(content, roiNorm: roiNorm);
  }

  /// 追加状态消息，用于外部流程（如设置变更后的提示）。
  void appendStatus(String msg) {
    _appendStatus(msg);
    notifyListeners();
  }

  /// 切换指定 turn 的思考区展开状态。
  void toggleThinkingBlock(int index) {
    if (index < 0 || index >= _turns.length) {
      return;
    }
    final turn = _turns[index];
    if (turn.thoughtSteps.isEmpty) {
      return;
    }
    turn.isThinkingExpanded = !turn.isThinkingExpanded;
    notifyListeners();
  }

  /// 将 turn 列表格式化为可复制文本。
  ///
  /// 将 [转写块] 与 [状态] 行按时间戳合并排序，避免「最早一条 WebSocket 连接日志」
  /// 因实现细节被挤到全文末尾。
  String formatMessagesForCopy() {
    final segments = <({DateTime at, String body})>[];

    for (final turn in _turns) {
      final body = _turnBlockForPlaintextCopy(turn);
      if (body.isEmpty) {
        continue;
      }
      segments.add((at: turn.createdAt, body: body));
    }

    for (final message in _messages.where((m) => m.role == MsgRole.status)) {
      segments.add((at: message.time, body: '[状态] ${message.text}\n'));
    }

    segments.sort((a, b) => a.at.compareTo(b.at));
    return segments.map((e) => e.body).join();
  }

  /// 单条 turn 的纯文本块（供复制与 [formatMessagesForCopy] 排序使用）。
  String _turnBlockForPlaintextCopy(ChatTurn turn) {
    final sb = StringBuffer();
    final who = turn.role == TurnRole.user ? '[用户]' : '[助手]';
    if (turn.thoughtSteps.isNotEmpty) {
      sb.writeln('$who [思考过程]');
      for (final step in turn.thoughtSteps) {
        if (step.type == StepType.thought) {
          final t = ChatTurn.stripInlineDataImageBase64(step.text ?? '');
          sb.writeln('  ℹ️ $t');
          continue;
        }
        final prefix = switch (step.toolStatus ?? ToolStatus.running) {
          ToolStatus.running => '  🔧',
          ToolStatus.success => '  ✓',
          ToolStatus.error => '  ❌',
        };
        sb.writeln('$prefix ${step.toolName ?? "工具"}');
        if ((step.resultText ?? '').isNotEmpty) {
          sb.writeln(
            '    ${ChatTurn.stripInlineDataImageBase64(step.resultText ?? '')}',
          );
        }
        if (step.previewImages.isNotEmpty) {
          sb.writeln('    [图像预览 ${step.previewImages.length} 张]');
        }
      }
    }
    final finalText = turn.filteredFinalContent;
    if (finalText.isNotEmpty) {
      sb.writeln('$who $finalText');
    }
    return sb.toString();
  }

  /// 仅供测试：在指定时间追加一条状态行（用于验证可复制文本的时间序）。
  @visibleForTesting
  void appendStatusForTest(String msg, DateTime time) {
    _messages.add(ChatMsg(role: MsgRole.status, text: msg, time: time));
  }

  void _onWsMessage(dynamic raw) {
    _logWs('raw', raw.toString());
    if (raw is! String) {
      _logWs('ignored_non_string', raw.runtimeType.toString());
      return;
    }

    try {
      _handleIncomingEvent(raw);
      notifyListeners();
    } catch (e, stack) {
      // 记录错误但继续运行
      debugPrint('Error processing WebSocket message: $e');
      debugPrint(stack.toString());
    }
  }

  /// 仅供测试：直接输入一条服务端事件并触发聚合。
  @visibleForTesting
  void handleIncomingEventForTest(String raw) {
    _handleIncomingEvent(raw);
  }

  /// 处理 turn 相关事件并按 message_id 聚合。
  void _handleIncomingEvent(String raw) {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      _logWs('invalid_json', raw);
      return;
    }

    final type = data['type'] as String? ?? '';
    final messageId = data['message_id'] as String?;
    if (messageId == null && type != 'turn_start') {
      _warnProtocolMismatch(type, data);
      return;
    }
    _logWs('parsed', 'type=$type, message_id=${messageId ?? "null"}, payload=$data');
    final turn = messageId == null ? null : _ensureTurn(messageId);

    switch (type) {
      case 'turn_start':
        if (turn != null) {
          _agentBusy = true;
          _logWs('dispatch', 'turn_start -> busy=true, turn=${turn.messageId}');
        }
        break;
      case 'thought_update':
        final text = (data['content'] ?? data['text'] ?? '').toString();
        if (turn != null && text.isNotEmpty) {
          turn.addThoughtStep(text);
          _logWs('dispatch', 'thought_update -> "${_truncateForLog(text)}"');
        }
        break;
      case 'tool_call_start':
        if (turn != null) {
          final toolName = data['tool_name'] as String?;
          final args = data['args'];
          turn.startToolCall(
            toolName: toolName,
            argsText: args == null ? null : jsonEncode(args),
          );
          _logWs(
            'dispatch',
            'tool_call_start -> tool=${toolName ?? "unknown"}, args=${args ?? "{}"}',
          );
        }
        break;
      case 'tool_call_end':
        if (turn != null) {
          final success = data['success'] as bool?;
          final status = (data['status'] as String? ?? '').toLowerCase();
          final resolvedStatus = success == null
              ? (status == 'success' ? ToolStatus.success : ToolStatus.error)
              : (success ? ToolStatus.success : ToolStatus.error);
          turn.endToolCall(
            status: resolvedStatus,
            resultText: (data['result'] ?? data['output'])?.toString(),
            previewImages: _decodeToolPreviewImages(data),
       );
          _logWs(
            'dispatch',
            'tool_call_end -> status=$resolvedStatus, duration_ms=${data['duration_ms']}',
          );
        }
        break;
      case 'content_update':
        final content = (data['content'] ?? '').toString();
        if (turn != null && content.isNotEmpty) {
          turn.updateContent(content);
          _logWs('dispatch', 'content_update -> "${_truncateForLog(content)}"');
        }
        break;
      case 'turn_end':
        if (turn != null) {
          turn.finish();
          _agentBusy = false;
          _appendTurnToMessages(turn);
          _logWs('dispatch', 'turn_end -> busy=false, turn=${turn.messageId}');
        }
        break;
      default:
        _logWs('unknown_type', 'type=$type, payload=$data');
        break;
    }
  }

  ChatTurn _ensureTurn(String messageId) {
    final existing = _turnByMessageId[messageId];
    if (existing != null) {
      return existing;
    }
    final created = ChatTurn(messageId: messageId, role: TurnRole.assistant);
    _turnByMessageId[messageId] = created;
    _turns.add(created);
    return created;
  }

  /// 将完成后的 turn 同步到兼容消息列表中。
  void _appendTurnToMessages(ChatTurn turn) {
    for (final step in turn.steps) {
      switch (step.type) {
        case StepType.thought:
          _messages.add(ChatMsg(role: MsgRole.status, text: step.text ?? ''));
          break;
        case StepType.toolCall:
          final callText = step.toolName == null ? '调用工具' : '调用工具: ${step.toolName}';
          _messages.add(
            ChatMsg(
              role: MsgRole.toolCall,
              text: callText,
              toolName: step.toolName,
            ),
          );
          if ((step.resultText ?? '').isNotEmpty) {
            _messages.add(
              ChatMsg(
                role: step.toolStatus == ToolStatus.error
                    ? MsgRole.error
                    : MsgRole.toolResult,
                text: step.resultText!,
                toolName: step.toolName,
              ),
            );
          }
          break;
        case StepType.content:
          if ((step.text ?? '').isNotEmpty) {
            _messages.add(ChatMsg(role: MsgRole.assistant, text: step.text!));
          }
          break;
        case StepType.done:
          break;
      }
    }
  }

  void _appendStatus(String msg) {
    final statusMsg = ChatMsg(role: MsgRole.status, text: msg);
    _messages.add(statusMsg);
  }

  /// 输出 WebSocket 协议调试日志，帮助定位后端协议与前端解析是否一致。
  void _logWs(String stage, String message) {
    if (!_enableWsDebugLog) {
      return;
    }
    debugPrint('[WS][$stage] $message');
  }

  String _truncateForLog(String text, {int max = 120}) {
    if (text.length <= max) {
      return text;
    }
    return '${text.substring(0, max)}...';
  }

  /// 解析 WebSocket `tool_call_end` 中的 [result_image_base64]（单张），供对话框预览。
  static List<Uint8List> decodeToolPreviewImagesForTest(Map<String, dynamic> data) =>
      _decodeToolPreviewImages(data);

  static List<Uint8List> _decodeToolPreviewImages(Map<String, dynamic> data) {
    final raw = data['result_image_base64'];
    if (raw is! String || raw.isEmpty) {
      return <Uint8List>[];
    }
    try {
      final bytes = base64Decode(raw);
      if (bytes.isEmpty) {
        return <Uint8List>[];
      }
      return <Uint8List>[bytes];
    } catch (_) {
      return <Uint8List>[];
    }
  }

  static Map<String, dynamic> _buildOutboundMessagePayload(
    String content, {
    Map<String, dynamic>? roiNorm,
  }) {
    final payload = <String, dynamic>{'type': 'message', 'content': content};
    if (roiNorm != null) {
      payload['roi_norm'] = roiNorm;
    }
    return payload;
  }

  void _warnProtocolMismatch(String type, Map<String, dynamic> payload) {
    _logWs('protocol_mismatch', 'missing message_id for type=$type, payload=$payload');
    if (_protocolMismatchWarned) {
      return;
    }
    _protocolMismatchWarned = true;
    _appendStatus(
      '后端协议不匹配：收到 "$type" 但缺少 message_id。'
      '当前前端仅支持 turn-step 协议，请检查 microclaw WebSocket 事件序列化实现。',
    );
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
