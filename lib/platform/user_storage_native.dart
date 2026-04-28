import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 非 Web 平台的用户配置存储 — 基于文件系统
Future<String?> readUserConfig() async {
  final file = await _userConfigFile();
  if (await file.exists()) {
    return file.readAsString();
  }
  return null;
}

Future<void> writeUserConfig(String json) async {
  final file = await _userConfigFile();
  await file.parent.create(recursive: true);
  await file.writeAsString(json);
}

Future<void> deleteUserConfig() async {
  final file = await _userConfigFile();
  if (await file.exists()) {
    await file.delete();
  }
}

Future<String> userConfigPath() async {
  final file = await _userConfigFile();
  return file.path;
}

// ── Internal ──────────────────────────────────────────────────────

Future<File> _userConfigFile() async {
  if (Platform.isMacOS || Platform.isLinux) {
    final home = Platform.environment['HOME'] ?? '.';
    return File('$home/.config/microscope_app/config.json');
  }
  // Windows / 其他平台 fallback 到 app support 目录
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/config.json');
}
