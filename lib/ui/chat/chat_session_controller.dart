import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'chat_models.dart';
import 'chat_protocol_mapper.dart';
import 'chat_display_models.dart';

/// 聊天会话控制器，封装连接生命周期、消息收发与协议解析。
///
/// 该控制器不直接依赖 Widget 树，通过 [ChangeNotifier] 向外暴露状态变更。
class ChatSessionController extends ChangeNotifier {
  /// 思维块预览文本的最大行数
  static const int previewLineCount = 5;

  final List<ChatMsg> _messages = [];
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  final StringBuffer _chunkBuffer = StringBuffer();

  bool _wsConnected = false;
  bool _agentBusy = false;

  // 新增：显示项列表
  final List<ChatDisplayItem> _displayItems = [];

  // 新增：当前活动的思维块
  ThinkingBlock? _currentBlock;

  /// 当前消息列表（只读视图）。
  List<ChatMsg> get messages => List.unmodifiable(_messages);

  /// 显示项列表（只读视图），包含消息项和思维块项
  List<ChatDisplayItem> get displayItems => List.unmodifiable(_displayItems);

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
    _currentBlock = null;
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
    // 添加用户消息到原始消息列表
    _messages.add(ChatMsg(role: MsgRole.user, text: normalized));
    _displayItems.add(MessageItem(_messages.last));

    // 创建新的思维块
    _currentBlock = ThinkingBlock(
      messages: [],
      startTime: DateTime.now(),
      isActive: true,
    );

    _agentBusy = true;
    _channel?.sink.add(jsonEncode({'type': 'message', 'content': normalized}));
    notifyListeners();
  }

  /// 追加状态消息，用于外部流程（如设置变更后的提示）。
  void appendStatus(String msg) {
    _appendStatus(msg);
    notifyListeners();
  }

  /// 切换思维块展开状态
  void toggleThinkingBlock(int index) {
    if (index < 0 || index >= _displayItems.length) {
      return;
    }
    final item = _displayItems[index];
    if (item is ThinkingItem) {
      item.block.isExpanded = !item.block.isExpanded;
      notifyListeners();
    }
  }

  /// 将全部显示项格式化为可复制文本。
  String formatMessagesForCopy() {
    final sb = StringBuffer();
    for (final item in _displayItems) {
      if (item is MessageItem) {
        final m = item.message;
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
      } else if (item is ThinkingItem) {
        sb.writeln('[思考过程]');
        for (final msg in item.block.messages) {
          final prefix = switch (msg.role) {
            MsgRole.toolCall => '  🔧 ${msg.toolName ?? "工具"}',
            MsgRole.toolResult => '  ✓ ${msg.toolName ?? "结果"}',
            MsgRole.error => '  ❌',
            MsgRole.status => '  ℹ️',
            _ => '',
          };
          if (prefix.isNotEmpty) {
            sb.writeln('$prefix ${msg.text}');
          }
        }
      }
    }
    return sb.toString();
  }

  void _onWsMessage(dynamic raw) {
    if (raw is! String) {
      return;
    }

    try {
      final result = ChatProtocolMapper.applyEvent(
        raw: raw,
        chunkBuffer: _chunkBuffer,
        agentBusy: _agentBusy,
        lastMessageRole: _messages.isNotEmpty ? _messages.last.role : null,
      );

      // 将消息添加到原始列表（保持兼容性）
      _messages.addAll(result.messages);

      // 分组逻辑：处理消息分组
      _processMessageGrouping(result.messages);

      // 更新活动状态
      _agentBusy = result.agentBusy;
      _updateCurrentBlockActivity();

      notifyListeners();
    } catch (e, stack) {
      // 记录错误但继续运行
      debugPrint('Error processing WebSocket message: $e');
      debugPrint(stack.toString());
    }
  }

  /// 处理消息分组逻辑
  void _processMessageGrouping(List<ChatMsg> messages) {
    for (final msg in messages) {
      if (_currentBlock != null && _isIntermediateMessage(msg)) {
        _currentBlock!.addMessage(msg);
      } else if (msg.role == MsgRole.assistant) {
        // 关闭当前思维块并添加助手消息
        if (_currentBlock != null && _currentBlock!.messages.isNotEmpty) {
          _displayItems.add(ThinkingItem(_currentBlock!));
        }
        _displayItems.add(MessageItem(msg));
        _currentBlock = null;
      }
    }
  }

  /// 更新当前思维块的活动状态
  void _updateCurrentBlockActivity() {
    if (_currentBlock != null) {
      _currentBlock!.isActive = _agentBusy;

      // 如果活动结束且有内容，添加到显示项
      if (!_agentBusy && _currentBlock!.messages.isNotEmpty) {
        _displayItems.add(ThinkingItem(_currentBlock!));
        _currentBlock = null;
      } else if (!_agentBusy && _currentBlock!.messages.isEmpty) {
        // 不要添加空的思维块
        _currentBlock = null;
      }
    }
  }

  void _appendStatus(String msg) {
    final statusMsg = ChatMsg(role: MsgRole.status, text: msg);
    _messages.add(statusMsg);
    _displayItems.add(MessageItem(statusMsg));
  }

  
  /// 判断是否为中间消息（应放入思维块）
  bool _isIntermediateMessage(ChatMsg msg) {
    return msg.role == MsgRole.toolCall ||
           msg.role == MsgRole.toolResult ||
           msg.role == MsgRole.error ||
           msg.role == MsgRole.status;
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
