import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'app_config.dart';

// ---------------------------------------------------------------------------
// Chat message model
// ---------------------------------------------------------------------------

enum MsgRole { user, assistant, toolCall, toolResult, error, status }

class ChatMsg {
  final MsgRole role;
  final String text;
  final DateTime time;
  final String? toolName;
  final Map<String, dynamic>? toolArgs;

  ChatMsg({
    required this.role,
    required this.text,
    DateTime? time,
    this.toolName,
    this.toolArgs,
  }) : time = time ?? DateTime.now();
}

// ---------------------------------------------------------------------------
// App entry
// ---------------------------------------------------------------------------

void main() {
  runApp(const MicroscopeApp());
}

class MicroscopeApp extends StatelessWidget {
  const MicroscopeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '显微镜代理',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4FC3F7),
      ),
      home: const HomePage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Home page — split layout: video (left) + chat (right)
// ---------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  /// 主界面：左侧为显微镜实时视频流，右侧为 Agent 对话区。
  ///
  /// [initialConfig] 与 [skipAutoConnect] 主要用于测试场景：
  /// - 提供 [initialConfig] 可跳过异步配置加载；
  /// - 将 [skipAutoConnect] 设为 `true` 时不会自动连接 WebSocket，
  ///   避免在测试环境中发起真实网络请求。
  const HomePage({
    super.key,
    this.initialConfig,
    this.skipAutoConnect = false,
  });

  /// 可选的初始配置，若提供则不再调用 [AppConfig.load]。
  final AppConfig? initialConfig;

  /// 是否跳过自动连接 WebSocket，仅在测试中使用。
  final bool skipAutoConnect;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AppConfig _config = AppConfig();
  bool _configLoaded = false;
  bool _isVideoLive = true;

  // WebSocket
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  bool _wsConnected = false;
  bool _agentBusy = false;

  // Chat
  final List<ChatMsg> _messages = [];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  StringBuffer _chunkBuffer = StringBuffer();
  bool _plainTextMode = false; // 纯文本模式：整段对话为单一可选中块，支持拖选部分复制

  @override
  void initState() {
    super.initState();
    // 在正常运行时按原逻辑加载配置并连接；
    // 在测试场景中可以通过传入 initialConfig / skipAutoConnect 来跳过异步流程。
    if (widget.initialConfig != null) {
      _config = widget.initialConfig!;
      _configLoaded = true;
      if (!widget.skipAutoConnect) {
        unawaited(_connectWs());
      }
    } else {
      _loadConfigAndConnect();
    }
  }

  @override
  void dispose() {
    _disconnectWs();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfigAndConnect() async {
    final config = await AppConfig.load();
    setState(() {
      _config = config;
      _configLoaded = true;
    });
    _connectWs();
  }

  // ── WebSocket ────────────────────────────────────────────────

  Future<void> _connectWs() async {
    _disconnectWs();
    final url = _config.wsUrl;
    _addStatus('正在连接 $url …');
    try {
      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _wsSub = _channel!.stream.listen(
        _onWsMessage,
        onError: (e) {
          setState(() {
            _wsConnected = false;
            _agentBusy = false;
          });
          _addStatus('WebSocket 错误: $e');
        },
        onDone: () {
          setState(() {
            _wsConnected = false;
            _agentBusy = false;
          });
          _addStatus('WebSocket 已断开');
        },
      );
      setState(() => _wsConnected = true);
      _addStatus('已连接 $url');
    } catch (e) {
      _channel = null;
      setState(() => _wsConnected = false);
      _addStatus('连接失败: $e');
    }
  }

  void _disconnectWs() {
    _wsSub?.cancel();
    _wsSub = null;
    _channel?.sink.close();
    _channel = null;
    _wsConnected = false;
  }

  void _onWsMessage(dynamic raw) {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = data['type'] as String? ?? '';

    setState(() {
      switch (type) {
        case 'chunk':
          _chunkBuffer.write(data['content'] ?? '');

        case 'tool_call':
          _flushChunks();
          _messages.add(ChatMsg(
            role: MsgRole.toolCall,
            text: '调用工具: ${data['name']}',
            toolName: data['name'] as String?,
            toolArgs: data['args'] as Map<String, dynamic>?,
          ));

        case 'tool_result':
          final output = data['output'] ?? data['result'] ?? '';
          _messages.add(ChatMsg(
            role: MsgRole.toolResult,
            text: output is String ? output : jsonEncode(output),
            toolName: data['name'] as String?,
          ));

        case 'done':
          _flushChunks();
          final fullResponse = data['full_response'] as String?;
          if (fullResponse != null && fullResponse.isNotEmpty) {
            final hasContent = _messages.isNotEmpty &&
                _messages.last.role == MsgRole.assistant;
            if (!hasContent) {
              _messages.add(ChatMsg(
                role: MsgRole.assistant,
                text: fullResponse,
              ));
            }
          }
          _agentBusy = false;

        case 'error':
          _flushChunks();
          _messages.add(ChatMsg(
            role: MsgRole.error,
            text: data['message'] ?? '未知错误',
          ));
          _agentBusy = false;

        case 'agent_start':
          _agentBusy = true;

        case 'agent_end':
          _agentBusy = false;
      }
    });

    _scrollToBottom();
  }

  void _flushChunks() {
    if (_chunkBuffer.isNotEmpty) {
      _messages.add(ChatMsg(
        role: MsgRole.assistant,
        text: _chunkBuffer.toString(),
      ));
      _chunkBuffer = StringBuffer();
    }
  }

  void _sendMessage() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || !_wsConnected) return;

    setState(() {
      _messages.add(ChatMsg(role: MsgRole.user, text: text));
      _agentBusy = true;
    });

    _channel?.sink.add(jsonEncode({'type': 'message', 'content': text}));
    _inputCtrl.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addStatus(String msg) {
    setState(() {
      _messages.add(ChatMsg(role: MsgRole.status, text: msg));
    });
  }

  // ── Settings dialog ──────────────────────────────────────────

  Future<void> _showSettings() async {
    final draft = _config.copy();
    final hostCtrl = TextEditingController(text: draft.piHost);
    final gwPortCtrl = TextEditingController(text: draft.gatewayPort.toString());
    final msPortCtrl = TextEditingController(text: draft.microscopyPort.toString());
    final wsPathCtrl = TextEditingController(text: draft.wsPath);
    final vidPathCtrl = TextEditingController(text: draft.videoPath);
    final userPath = await AppConfig.userConfigPath();

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          void updatePreview() => setDialogState(() {
                draft.piHost = hostCtrl.text.trim();
                draft.gatewayPort =
                    int.tryParse(gwPortCtrl.text.trim()) ?? draft.gatewayPort;
                draft.microscopyPort =
                    int.tryParse(msPortCtrl.text.trim()) ?? draft.microscopyPort;
                draft.wsPath = wsPathCtrl.text.trim();
                draft.videoPath = vidPathCtrl.text.trim();
              });

          return AlertDialog(
            title: const Text('连接设置'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: hostCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Pi 主机地址',
                        hintText: '10.198.31.242',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.dns),
                      ),
                      onChanged: (_) => updatePreview(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: gwPortCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Gateway 端口',
                              hintText: '42617',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => updatePreview(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: msPortCtrl,
                            decoration: const InputDecoration(
                              labelText: '显微镜服务端口',
                              hintText: '5000',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => updatePreview(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: wsPathCtrl,
                            decoration: const InputDecoration(
                              labelText: 'WS 路径',
                              hintText: '/ws/chat',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => updatePreview(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: vidPathCtrl,
                            decoration: const InputDecoration(
                              labelText: '视频路径',
                              hintText: '/video_feed',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => updatePreview(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Live preview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('实际地址预览',
                              style: Theme.of(ctx).textTheme.labelSmall),
                          const SizedBox(height: 4),
                          SelectableText(
                            'WS:  ${draft.wsUrl}\n视频: ${draft.videoUrl}',
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Config file paths
                    Text(
                      '开发配置: assets/config.json（随应用分发）\n'
                      '用户配置: $userPath',
                      style: Theme.of(ctx)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(ctx).colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.end,
            actions: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () async {
                    await AppConfig.resetUser();
                    Navigator.pop(ctx, null);
                    if (mounted) {
                      _addStatus('已删除用户配置，重新加载开发默认值');
                      _loadConfigAndConnect();
                    }
                  },
                  child: const Text('恢复默认'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('应用并保存'),
              ),
            ],
          );
        });
      },
    );

    if (result == true) {
      setState(() => _config = draft);
      await _config.saveUser();
      _addStatus('配置已保存到用户文件');
      _connectWs();
    }

    hostCtrl.dispose();
    gwPortCtrl.dispose();
    msPortCtrl.dispose();
    wsPathCtrl.dispose();
    vidPathCtrl.dispose();
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_configLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('显微镜代理'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: _wsConnected ? Colors.greenAccent : Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  _wsConnected ? '已连接' : '未连接',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新连接',
            onPressed: _connectWs,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '连接设置',
            onPressed: _showSettings,
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(flex: 3, child: _buildVideoPanel(cs)),
          const VerticalDivider(width: 1),
          Expanded(flex: 2, child: _buildChatPanel(cs)),
        ],
      ),
    );
  }

  // ── Video panel ──────────────────────────────────────────────

  Widget _buildVideoPanel(ColorScheme cs) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: cs.surfaceContainerHighest,
          child: Row(
            children: [
              const Icon(Icons.videocam, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _config.videoUrl,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                icon: Icon(_isVideoLive ? Icons.pause : Icons.play_arrow),
                iconSize: 20,
                tooltip: _isVideoLive ? '暂停' : '继续',
                onPressed: () => setState(() => _isVideoLive = !_isVideoLive),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.black,
            child: _isVideoLive
                ? Mjpeg(
                    stream: _config.videoUrl,
                    isLive: true,
                    timeout: const Duration(seconds: 60),
                    fit: BoxFit.contain,
                    error: (context, error, stack) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam_off, size: 48, color: cs.error),
                          const SizedBox(height: 12),
                          Text('视频连接失败', style: TextStyle(color: cs.error)),
                          const SizedBox(height: 4),
                          SelectableText(
                            error.toString(),
                            style: Theme.of(context).textTheme.bodySmall ??
                                const TextStyle(),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pause_circle_filled,
                            size: 48, color: cs.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text(
                          '视频已暂停',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  String _formatMessagesForCopy() {
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

  Future<void> _copyAllMessages() async {
    if (_messages.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _formatMessagesForCopy()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制全部对话到剪贴板')),
      );
    }
  }

  // ── Chat panel ───────────────────────────────────────────────

  Widget _buildChatPanel(ColorScheme cs) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: cs.surfaceContainerHighest,
          child: Row(
            children: [
              const Icon(Icons.chat, size: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text('Agent 对话')),
              if (_messages.isNotEmpty) ...[
                IconButton(
                  icon: Icon(
                    _plainTextMode ? Icons.chat_bubble : Icons.text_snippet,
                    size: 20,
                  ),
                  tooltip: _plainTextMode ? '切换为气泡视图' : '切换为纯文本（可拖选部分复制）',
                  onPressed: () => setState(() => _plainTextMode = !_plainTextMode),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_all, size: 20),
                  tooltip: '复制全部对话',
                  onPressed: _copyAllMessages,
                ),
              ],
              if (_agentBusy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Text(
                    '发送消息开始对话',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              : _plainTextMode
                  ? _buildPlainTextView(cs)
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _buildMessage(_messages[i], cs),
                    ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  decoration: InputDecoration(
                    hintText: '输入指令…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _wsConnected && !_agentBusy ? _sendMessage : null,
                icon: const Icon(Icons.send),
                tooltip: '发送',
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 纯文本视图：整段对话为单一 SelectableText，支持鼠标拖选任意部分后 Cmd+C 复制
  Widget _buildPlainTextView(ColorScheme cs) {
    final text = _formatMessagesForCopy();
    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: cs.onSurface,
          height: 1.5,
        ),
      ),
    );
  }

  // ── Message bubbles ──────────────────────────────────────────

  Widget _buildMessage(ChatMsg msg, ColorScheme cs) {
    return switch (msg.role) {
      MsgRole.user => _userBubble(msg, cs),
      MsgRole.assistant => _assistantBubble(msg, cs),
      MsgRole.toolCall => _toolCallCard(msg, cs),
      MsgRole.toolResult => _toolResultCard(msg, cs),
      MsgRole.error => _errorCard(msg, cs),
      MsgRole.status => _statusLine(msg, cs),
    };
  }

  Widget _userBubble(ChatMsg msg, ColorScheme cs) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(msg.text, style: TextStyle(color: cs.onPrimary)),
      ),
    );
  }

  Widget _assistantBubble(ChatMsg msg, ColorScheme cs) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(msg.text),
      ),
    );
  }

  Widget _toolCallCard(ChatMsg msg, ColorScheme cs) {
    final argsStr = msg.toolArgs != null
        ? const JsonEncoder.withIndent('  ').convert(msg.toolArgs)
        : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: cs.tertiary.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        dense: true,
        leading: Icon(Icons.build, size: 18, color: cs.tertiary),
        title: SelectableText(
          '工具调用: ${msg.toolName ?? "?"}',
          style: TextStyle(fontSize: 13, color: cs.tertiary),
        ),
        children: [
          if (argsStr.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: cs.surfaceContainerHighest,
              child: SelectableText(
                argsStr,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolResultCard(ChatMsg msg, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: cs.secondary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        dense: true,
        initiallyExpanded: false,
        leading:
            Icon(Icons.check_circle_outline, size: 18, color: cs.secondary),
        title: SelectableText(
          '工具结果: ${msg.toolName ?? ""}',
          style: TextStyle(fontSize: 13, color: cs.secondary),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: cs.surfaceContainerHighest,
            child: SelectableText(
              msg.text,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(ChatMsg msg, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: cs.error),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              msg.text,
              style: TextStyle(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusLine(ChatMsg msg, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: SelectableText(
          msg.text,
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
