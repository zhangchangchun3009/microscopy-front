import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// VLM settings tab inside the connection settings dialog.
///
/// Backend endpoints:
/// - GET  {gatewayBaseUrl}/api/vlm/config
/// - PUT  {gatewayBaseUrl}/api/vlm/config
///
/// Notes:
/// - API key is never returned by GET; UI treats it as "already configured"
///   via `has_api_key`.
class VlmSettingsTab extends StatefulWidget {
  final String gatewayBaseUrl;

  const VlmSettingsTab({super.key, required this.gatewayBaseUrl});

  @override
  State<VlmSettingsTab> createState() => _VlmSettingsTabState();
}

class _VlmSettingsTabState extends State<VlmSettingsTab> {
  final _apiUrlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _timeoutCtrl = TextEditingController();
  final _maxTokensCtrl = TextEditingController();
  final _thinkingBudgetCtrl = TextEditingController();

  bool _enableThinking = true;
  bool _hasApiKey = false;
  bool _clearApiKey = false;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VlmSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gatewayBaseUrl != widget.gatewayBaseUrl) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('${widget.gatewayBaseUrl}/api/vlm/config');
      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = '加载 VLM 配置失败: ${response.statusCode}';
        });
        return;
      }

      final data = jsonDecode(body) as Map<String, dynamic>;

      _apiUrlCtrl.text = (data['api_url'] ?? '').toString();
      _modelCtrl.text = (data['model_name'] ?? '').toString();
      _timeoutCtrl.text = (data['timeout_secs'] ?? 120).toString();
      _maxTokensCtrl.text = ((data['max_tokens'] ?? 4096) as num).toInt().toString();
      _thinkingBudgetCtrl.text =
          ((data['thinking_budget'] ?? 81920) as num).toInt().toString();
      _enableThinking = (data['enable_thinking'] ?? true) as bool;
      _hasApiKey = (data['has_api_key'] ?? false) as bool;
      _clearApiKey = false;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '无法连接 Gateway: $e';
      });
    }
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_apiUrlCtrl.text.trim().isEmpty || _modelCtrl.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请填写 API 地址和模型名称')),
      );
      return;
    }

    final timeout = int.tryParse(_timeoutCtrl.text.trim());
    final maxTokens = int.tryParse(_maxTokensCtrl.text.trim());
    final thinkingBudget = int.tryParse(_thinkingBudgetCtrl.text.trim());
    if (timeout == null || maxTokens == null || thinkingBudget == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('超时/最大Token/思考预算必须是数字')),
      );
      return;
    }

    final body = <String, dynamic>{
      'api_url': _apiUrlCtrl.text.trim(),
      'model_name': _modelCtrl.text.trim(),
      'timeout_secs': timeout,
      'max_tokens': maxTokens,
      'enable_thinking': _enableThinking,
      'thinking_budget': thinkingBudget,
    };

    // Only send api_key when user filled it or explicitly clears it.
    if (_apiKeyCtrl.text.trim().isNotEmpty) {
      body['api_key'] = _apiKeyCtrl.text.trim();
      _clearApiKey = false;
    } else if (_clearApiKey) {
      body['api_key'] = '';
    }

    try {
      final uri = Uri.parse('${widget.gatewayBaseUrl}/api/vlm/config');
      final client = HttpClient();
      final request = await client.openUrl('PUT', uri);
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close();
      final respBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        messenger.showSnackBar(
          SnackBar(content: Text('保存失败: ${response.statusCode} $respBody')),
        );
        return;
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('VLM 配置已保存')),
      );

      await _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _apiUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'API 地址',
                    hintText: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _apiKeyCtrl,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: _hasApiKey
                        ? '已配置（留空=保持不变；勾选清空可重置）'
                        : '未配置（填写后保存）',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _clearApiKey
                            ? Icons.delete_forever
                            : Icons.delete_outline,
                      ),
                      tooltip: '清空 API Key（保存后生效）',
                      onPressed: () {
                        setState(() => _clearApiKey = !_clearApiKey);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _modelCtrl,
                  decoration: const InputDecoration(
                    labelText: '模型名称',
                    hintText: 'qwen3-vl-plus',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _timeoutCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '超时(秒)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _maxTokensCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '最大 Token',
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text('启用思考链（thinking）'),
                  value: _enableThinking,
                  onChanged: (v) => setState(() => _enableThinking = v),
                ),
                if (_enableThinking) ...[
                  TextField(
                    controller: _thinkingBudgetCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '思考预算',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _save,
            child: const Text('保存 VLM 配置'),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    _timeoutCtrl.dispose();
    _maxTokensCtrl.dispose();
    _thinkingBudgetCtrl.dispose();
    super.dispose();
  }
}

