import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// LLM settings tab inside the connection settings dialog.
///
/// Backend endpoints:
/// - GET  {gatewayBaseUrl}/api/llm/config
/// - PUT  {gatewayBaseUrl}/api/llm/config
///
/// Notes:
/// - API key is never returned by GET; UI treats it as "already configured"
///   via `has_api_key`.
/// - base_url is stored as `custom:<url>` in default_provider on the server.
/// - All config changes take effect immediately (next message uses new config).
class LlmSettingsTab extends StatefulWidget {
  final String gatewayBaseUrl;

  const LlmSettingsTab({super.key, required this.gatewayBaseUrl});

  @override
  State<LlmSettingsTab> createState() => _LlmSettingsTabState();
}

class _LlmSettingsTabState extends State<LlmSettingsTab> {
  final _baseUrlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _timeoutCtrl = TextEditingController();
  final _maxTokensCtrl = TextEditingController();
  final _thinkingBudgetCtrl = TextEditingController();

  String _wireApi = 'chat_completions';
  bool _enableThinking = false;
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
  void didUpdateWidget(covariant LlmSettingsTab oldWidget) {
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
      final uri = '${widget.gatewayBaseUrl}/api/llm/config';
      final response = await Dio().get(uri);

      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = '加载 LLM 配置失败: ${response.statusCode}';
        });
        return;
      }

      final data = response.data as Map<String, dynamic>;

      _baseUrlCtrl.text = (data['base_url'] ?? '').toString();
      _modelCtrl.text = (data['model_name'] ?? '').toString();
      _wireApi = (data['wire_api'] ?? 'chat_completions').toString();
      _timeoutCtrl.text = (data['timeout_secs'] ?? 120).toString();
      _maxTokensCtrl.text =
          ((data['max_tokens'] ?? 4096) as num).toInt().toString();
      _thinkingBudgetCtrl.text =
          ((data['thinking_budget'] ?? 8192) as num).toInt().toString();
      _enableThinking = (data['enable_thinking'] ?? false) as bool;
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
    if (_baseUrlCtrl.text.trim().isEmpty || _modelCtrl.text.trim().isEmpty) {
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
      'base_url': _baseUrlCtrl.text.trim(),
      'model_name': _modelCtrl.text.trim(),
      'wire_api': _wireApi,
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
      final uri = '${widget.gatewayBaseUrl}/api/llm/config';
      final response = await Dio().put(
        uri,
        data: body,
        options: Options(contentType: Headers.jsonContentType),
      );

      if (response.statusCode != 200) {
        messenger.showSnackBar(
          SnackBar(content: Text('保存失败: ${response.statusCode}')),
        );
        return;
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('LLM 配置已保存')),
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
                  controller: _baseUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'API 地址',
                    hintText: 'https://www.aiinstrum.com/v1',
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
                    hintText: 'qwen-text-aliyun',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _wireApi,
                  decoration: const InputDecoration(
                    labelText: 'Wire API',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'chat_completions',
                      child: Text('chat_completions'),
                    ),
                    DropdownMenuItem(
                      value: 'responses',
                      child: Text('responses'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _wireApi = v);
                  },
                ),
                const SizedBox(height: 10),
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
            child: const Text('保存 LLM 配置'),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    _timeoutCtrl.dispose();
    _maxTokensCtrl.dispose();
    _thinkingBudgetCtrl.dispose();
    super.dispose();
  }
}
