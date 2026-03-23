import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// 两层配置：
///   1. assets/config.json  — 开发默认值，版本控制，改 Pi IP/端口不用改代码
///   2. ~/.config/microscope_app/config.json — 用户覆盖，通过设置弹窗修改
///
/// 加载顺序：硬编码 fallback → asset → 用户文件（后者覆盖前者）
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

  /// 加载配置：hardcoded → assets/config.json → 用户配置文件
  static Future<AppConfig> load() async {
    final config = AppConfig();

    // Layer 1: 开发配置（asset）
    try {
      final assetStr = await rootBundle.loadString('assets/config.json');
      config.applyJson(jsonDecode(assetStr) as Map<String, dynamic>);
    } catch (_) {
      // asset 缺失不影响启动
    }

    // Layer 2: 用户配置（本地文件）
    try {
      final file = await _userConfigFile();
      if (await file.exists()) {
        final userStr = await file.readAsString();
        config.applyJson(jsonDecode(userStr) as Map<String, dynamic>);
      }
    } catch (_) {
      // 文件不存在或格式错误，忽略
    }

    return config;
  }

  // ── Save (user layer only) ──────────────────────────────────

  Future<void> saveUser() async {
    final file = await _userConfigFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(toJson()),
    );
  }

  /// 删除用户配置文件，恢复到开发默认值
  static Future<void> resetUser() async {
    final file = await _userConfigFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ── User config path ────────────────────────────────────────

  static Future<File> _userConfigFile() async {
    if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '.';
      return File('$home/.config/microscope_app/config.json');
    }
    // Windows / 其他平台 fallback 到 app support 目录
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/config.json');
  }

  /// 返回用户配置文件路径（供 UI 显示）
  static Future<String> userConfigPath() async {
    final file = await _userConfigFile();
    return file.path;
  }
}
