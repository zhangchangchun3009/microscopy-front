import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_config.dart';
import 'microscopy_socket.dart';
import 'ui/chat/chat_panel.dart';
import 'ui/chat/chat_session_controller.dart';
import 'ui/layout/right_chat_split_layout.dart';
import 'ui/settings/connection_settings_dialog.dart';
import 'ui/video/roi_overlay.dart';
import 'ui/video/video_stage.dart';

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
      title: '显微镜智能助手',
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
  const HomePage({super.key, this.initialConfig, this.skipAutoConnect = false});

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
  RoiRectNorm? _currentRoi;

  /// 与 microscopy_server 的 Socket.IO，用于 get_settings 初始化及后续进度等
  final MicroscopySocket _microscopySocket = MicroscopySocket();

  // Chat state: 会话逻辑下沉到控制器，页面仅负责组装与调度。
  final ChatSessionController _chatSession = ChatSessionController();
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _plainTextMode = false; // 纯文本模式：整段对话为单一可选中块，支持拖选部分复制

  @override
  void initState() {
    super.initState();
    _chatSession.addListener(_onChatSessionChanged);
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
    _chatSession.removeListener(_onChatSessionChanged);
    _chatSession.dispose();
    _microscopySocket.disconnect();
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
    // 与 Web 前端一致：先连 microscopy_server Socket.IO 并 get_settings，再拉 MJPEG 才正常
    _microscopySocket.connect(
      'http://${_config.piHost}:${_config.microscopyPort}',
    );
    await _connectWs();
  }

  /// 页面侧连接调度：具体连接/解析逻辑由 [ChatSessionController] 负责。
  Future<void> _connectWs() async {
    await _chatSession.connect(_config.wsUrl);
  }

  void _sendMessage(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty || !_chatSession.wsConnected) return;
    _chatSession.sendMessage(
      normalized,
      roiNorm: _currentRoi?.toPayload(),
    );
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

  void _onChatSessionChanged() {
    if (!mounted) return;
    setState(() {});
    _scrollToBottom();
  }

  // ── Settings dialog ──────────────────────────────────────────

  Future<void> _showSettings() async {
    final userPath = await AppConfig.userConfigPath();
    if (!mounted) return;
    final result = await showConnectionSettingsDialog(
      context: context,
      initialConfig: _config,
      userConfigPath: userPath,
    );
    if (result == null || !mounted) return;

    switch (result.action) {
      case ConnectionSettingsAction.reset:
        await AppConfig.resetUser();
        _chatSession.appendStatus('已删除用户配置，重新加载开发默认值');
        await _loadConfigAndConnect();
        break;
      case ConnectionSettingsAction.cancel:
        break;
      case ConnectionSettingsAction.apply:
        setState(() => _config = result.draft);
        await _config.saveUser();
        _chatSession.appendStatus('配置已保存到用户文件');
        _microscopySocket.disconnect();
        _microscopySocket.connect(
          'http://${_config.piHost}:${_config.microscopyPort}',
        );
        await _connectWs();
        break;
    }
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_configLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('显微镜智能助手'),
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
                  color: _chatSession.wsConnected
                      ? Colors.greenAccent
                      : Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  _chatSession.wsConnected ? '已连接' : '未连接',
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
      body: RightChatSplitLayout(
        leftPane: VideoStage(
          videoUrl: _config.videoUrl,
          isVideoLive: _isVideoLive,
          onToggleLive: () => setState(() => _isVideoLive = !_isVideoLive),
          onRoiChanged: (roi) => setState(() => _currentRoi = roi),
        ),
        rightChatPane: ChatPanel(
          turns: _chatSession.turns,
          inputController: _inputCtrl,
          scrollController: _scrollCtrl,
          plainTextMode: _plainTextMode,
          agentBusy: _chatSession.agentBusy,
          wsConnected: _chatSession.wsConnected,
          plainTextTranscript: _chatSession.formatMessagesForCopy(),
          onTogglePlainTextMode: () =>
              setState(() => _plainTextMode = !_plainTextMode),
          onCopyAllMessages: _copyAllMessages,
          onSendMessage: _sendMessage,
        ),
      ),
    );
  }

  Future<void> _copyAllMessages() async {
    if (_chatSession.messages.isEmpty) return;
    await Clipboard.setData(
      ClipboardData(text: _chatSession.formatMessagesForCopy()),
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已复制全部对话到剪贴板')));
    }
  }
}
