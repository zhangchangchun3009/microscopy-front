import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'chat_models.dart';
import 'chat_protocol_mapper.dart';

/// 聊天会话控制器，封装连接生命周期、消息收发与协议解析。
///
/// 该控制器不直接依赖 Widget 树，通过 [ChangeNotifier] 向外暴露状态变更。
class ChatSessionController extends ChangeNotifier {
  final List<ChatMsg> _messages = [];
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  final StringBuffer _chunkBuffer = StringBuffer();

  bool _wsConnected = false;
  bool _agentBusy = false;

  /// 当前消息列表（只读视图）。
  List<ChatMsg> get messages => List.unmodifiable(_messages);

  /// WebSocket 是否已连接。
  bool get wsConnected => _wsConnected;

  /// Agent 是否处于处理中。
  bool get agentBusy => _agentBusy;

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
    notifyListeners();
  }

  /// 发送用户消息。
  ///
  /// - 若 [text] 为空或未连接，直接忽略；
  /// - 成功发送后会追加一条用户消息并将 [agentBusy] 置为 `true`。
  void sendMessage(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty || !_wsConnected) {
      return;
    }
    _messages.add(ChatMsg(role: MsgRole.user, text: normalized));
    _agentBusy = true;
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
    for (final m in _messages) {
      final prefix = switch (m.role) {
        MsgRole.user => '[用户]',
        MsgRole.assistant => '[助手]',
        MsgRole.toolCall => '[工具调用: ${m.toolName ?? "?"}]',
        MsgRole.toolResult => '[工具结果: ${m.toolName ?? ""}]',
        MsgRole.error => '[错误]',
        MsgRole.status => '[状态]',
      };
      sb.writeln('$prefix ${m.text}');
      if (m.toolArgs != null && m.toolArgs!.isNotEmpty) {
        sb.writeln(const JsonEncoder.withIndent('  ').convert(m.toolArgs));
      }
    }
    return sb.toString();
  }

  void _onWsMessage(dynamic raw) {
    if (raw is! String) {
      return;
    }
    final result = ChatProtocolMapper.applyEvent(
      raw: raw,
      chunkBuffer: _chunkBuffer,
      agentBusy: _agentBusy,
      lastMessageRole: _messages.isNotEmpty ? _messages.last.role : null,
    );
    _messages.addAll(result.messages);
    _agentBusy = result.agentBusy;
    notifyListeners();
  }

  void _appendStatus(String msg) {
    _messages.add(ChatMsg(role: MsgRole.status, text: msg));
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
