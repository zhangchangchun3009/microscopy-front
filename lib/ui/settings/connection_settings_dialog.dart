import 'package:flutter/material.dart';

import '../../app_config.dart';

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
  final draft = initialConfig.copy();
  final hostCtrl = TextEditingController(text: draft.piHost);
  final gwPortCtrl = TextEditingController(text: draft.gatewayPort.toString());
  final msPortCtrl = TextEditingController(
    text: draft.microscopyPort.toString(),
  );
  final wsPathCtrl = TextEditingController(text: draft.wsPath);
  final vidPathCtrl = TextEditingController(text: draft.videoPath);

  final result = await showDialog<ConnectionSettingsDialogResult>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          ctx,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '实际地址预览',
                            style: Theme.of(ctx).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            'WS:  ${draft.wsUrl}\n视频: ${draft.videoUrl}',
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
                      '用户配置: $userConfigPath',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.outline,
                      ),
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
                  onPressed: () {
                    Navigator.pop(
                      ctx,
                      ConnectionSettingsDialogResult(
                        action: ConnectionSettingsAction.reset,
                        draft: draft.copy(),
                      ),
                    );
                  },
                  child: const Text('恢复默认'),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    ctx,
                    ConnectionSettingsDialogResult(
                      action: ConnectionSettingsAction.cancel,
                      draft: draft.copy(),
                    ),
                  );
                },
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    ctx,
                    ConnectionSettingsDialogResult(
                      action: ConnectionSettingsAction.apply,
                      draft: draft.copy(),
                    ),
                  );
                },
                child: const Text('应用并保存'),
              ),
            ],
          );
        },
      );
    },
  );

  hostCtrl.dispose();
  gwPortCtrl.dispose();
  msPortCtrl.dispose();
  wsPathCtrl.dispose();
  vidPathCtrl.dispose();

  return result;
}
