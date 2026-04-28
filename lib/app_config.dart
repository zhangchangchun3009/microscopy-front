import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'platform/user_storage_native.dart'
    if (dart.library.js_interop) 'platform/user_storage_web.dart'
    as storage;

/// 两层配置：
///   1. assets/config.json  — 开发默认值，版本控制，改 Pi IP/端口不用改代码
///   2. 用户配置 — 通过设置弹窗修改
///      - 非 Web: ~/.config/microscope_app/config.json
///      - Web:    localStorage['microscope_app_config']
///
/// 加载顺序：硬编码 fallback → asset → 用户配置（后者覆盖前者）
class AppConfig {
  String piHost;
  int gatewayPort;
  int microscopyPort;
  String wsPath;
  String videoPath;

  AppConfig({
    this.piHost = '127.0.0.1',
    this.gatewayPort = 42617,
    this.microscopyPort = 5000,
    this.wsPath = '/ws/chat',
    this.videoPath = '/video_feed',
  });

  String get wsUrl => 'ws://$piHost:$gatewayPort$wsPath';
  String get videoUrl => 'http://$piHost:$microscopyPort$videoPath';

  // ── Serialization ────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'pi_host': piHost,
    'gateway_port': gatewayPort,
    'microscopy_port': microscopyPort,
    'ws_path': wsPath,
    'video_path': videoPath,
  };

  void applyJson(Map<String, dynamic> json) {
    if (json['pi_host'] is String) piHost = json['pi_host'];
    if (json['gateway_port'] is int) gatewayPort = json['gateway_port'];
    if (json['microscopy_port'] is int) {
      microscopyPort = json['microscopy_port'];
    }
    if (json['ws_path'] is String) wsPath = json['ws_path'];
    if (json['video_path'] is String) videoPath = json['video_path'];
  }

  AppConfig copy() => AppConfig(
    piHost: piHost,
    gatewayPort: gatewayPort,
    microscopyPort: microscopyPort,
    wsPath: wsPath,
    videoPath: videoPath,
  );

  // ── Load ─────────────────────────────────────────────────────

  /// 加载配置：hardcoded → assets/config.json → 用户配置
  static Future<AppConfig> load() async {
    final config = AppConfig();

    // Layer 1: 开发配置（asset）
    try {
      final assetStr = await rootBundle.loadString('assets/config.json');
      config.applyJson(jsonDecode(assetStr) as Map<String, dynamic>);
    } catch (_) {
      // asset 缺失不影响启动
    }

    // Layer 2: 用户配置（平台存储）
    try {
      final userStr = await storage.readUserConfig();
      if (userStr != null) {
        config.applyJson(jsonDecode(userStr) as Map<String, dynamic>);
      }
    } catch (_) {
      // 配置不存在或格式错误，忽略
    }

    return config;
  }

  // ── Save (user layer only) ──────────────────────────────────

  Future<void> saveUser() async {
    await storage.writeUserConfig(
      const JsonEncoder.withIndent('  ').convert(toJson()),
    );
  }

  /// 删除用户配置，恢复到开发默认值
  static Future<void> resetUser() async {
    await storage.deleteUserConfig();
  }

  // ── User config path ────────────────────────────────────────

  /// 返回用户配置路径/描述（供 UI 显示）
  static Future<String> userConfigPath() async {
    return storage.userConfigPath();
  }
}
