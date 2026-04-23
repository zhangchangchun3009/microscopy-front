import 'package:flutter/material.dart';

import '../../app_config.dart';
import 'llm_settings_tab.dart';
import 'vlm_settings_tab.dart';

/// 连接设置弹窗动作类型。
enum ConnectionSettingsAction { apply, reset, cancel }

/// 连接设置弹窗返回值。
class ConnectionSettingsDialogResult {
  /// 创建返回值对象。
  const ConnectionSettingsDialogResult({
    required this.action,
    required this.draft,
  });

  /// 用户在弹窗中的动作。
  final ConnectionSettingsAction action;

  /// 用户编辑后的配置草稿（reset/cancel 时也会携带当前草稿快照）。
  final AppConfig draft;
}

/// 显示连接设置弹窗并返回用户操作结果。
Future<ConnectionSettingsDialogResult?> showConnectionSettingsDialog({
  required BuildContext context,
  required AppConfig initialConfig,
  required String userConfigPath,
}) async {
  return showDialog<ConnectionSettingsDialogResult>(
    context: context,
    builder: (_) => ConnectionSettingsDialog(
      initialConfig: initialConfig,
      userConfigPath: userConfigPath,
    ),
  );
}

class ConnectionSettingsDialog extends StatefulWidget {
  const ConnectionSettingsDialog({
    super.key,
    required this.initialConfig,
    required this.userConfigPath,
  });

  final AppConfig initialConfig;
  final String userConfigPath;

  @override
  State<ConnectionSettingsDialog> createState() => _ConnectionSettingsDialogState();
}

class _ConnectionSettingsDialogState extends State<ConnectionSettingsDialog>
    with TickerProviderStateMixin {
  late AppConfig _draft;
  late TabController _tabController;
  late TextEditingController _hostCtrl;
  late TextEditingController _gwPortCtrl;
  late TextEditingController _msPortCtrl;
  late TextEditingController _wsPathCtrl;
  late TextEditingController _vidPathCtrl;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialConfig.copy();
    _tabController = TabController(length: 3, vsync: this);
    _hostCtrl = TextEditingController(text: _draft.piHost);
    _gwPortCtrl = TextEditingController(text: _draft.gatewayPort.toString());
    _msPortCtrl = TextEditingController(text: _draft.microscopyPort.toString());
    _wsPathCtrl = TextEditingController(text: _draft.wsPath);
    _vidPathCtrl = TextEditingController(text: _draft.videoPath);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hostCtrl.dispose();
    _gwPortCtrl.dispose();
    _msPortCtrl.dispose();
    _wsPathCtrl.dispose();
    _vidPathCtrl.dispose();
    super.dispose();
  }

  void _updatePreview() {
    setState(() {
      _draft.piHost = _hostCtrl.text.trim();
      _draft.gatewayPort =
          int.tryParse(_gwPortCtrl.text.trim()) ?? _draft.gatewayPort;
      _draft.microscopyPort =
          int.tryParse(_msPortCtrl.text.trim()) ?? _draft.microscopyPort;
      _draft.wsPath = _wsPathCtrl.text.trim();
      _draft.videoPath = _vidPathCtrl.text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Text('显微镜设置'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '关闭',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 480,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '连接设置'),
                Tab(text: 'LLM 设置'),
                Tab(text: 'VLM 设置'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Connection settings
                  Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _hostCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Pi 主机地址',
                                    hintText: '10.198.31.242',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.dns),
                                  ),
                                  onChanged: (_) => _updatePreview(),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _gwPortCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Gateway 端口',
                                          hintText: '42617',
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType:
                                            TextInputType.number,
                                        onChanged: (_) => _updatePreview(),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _msPortCtrl,
                                        decoration: const InputDecoration(
                                          labelText: '显微镜服务端口',
                                          hintText: '5000',
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType:
                                            TextInputType.number,
                                        onChanged: (_) => _updatePreview(),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _wsPathCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'WS 路径',
                                          hintText: '/ws/chat',
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (_) => _updatePreview(),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _vidPathCtrl,
                                        decoration: const InputDecoration(
                                          labelText: '视频路径',
                                          hintText: '/video_feed',
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (_) => _updatePreview(),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '实际地址预览',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      SelectableText(
                                        'WS:  ${_draft.wsUrl}\n视频: ${_draft.videoUrl}',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '开发配置: assets/config.json（随应用分发）\n'
                                  '用户配置: ${widget.userConfigPath}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(
                                  context,
                                  ConnectionSettingsDialogResult(
                                    action:
                                        ConnectionSettingsAction.reset,
                                    draft: _draft.copy(),
                                  ),
                                );
                              },
                              child: const Text('恢复默认'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                Navigator.pop(
                                  context,
                                  ConnectionSettingsDialogResult(
                                    action: ConnectionSettingsAction.apply,
                                    draft: _draft.copy(),
                                  ),
                                );
                              },
                              child: const Text('保存'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Tab 2: LLM settings
                  LlmSettingsTab(
                    key: ValueKey('llm:${_draft.piHost}:${_draft.gatewayPort}'),
                    gatewayBaseUrl:
                        'http://${_draft.piHost}:${_draft.gatewayPort}',
                  ),
                  // Tab 3: VLM settings
                  VlmSettingsTab(
                    key: ValueKey('vlm:${_draft.piHost}:${_draft.gatewayPort}'),
                    gatewayBaseUrl:
                        'http://${_draft.piHost}:${_draft.gatewayPort}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
