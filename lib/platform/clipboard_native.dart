import 'package:flutter/services.dart';

/// 原生平台剪贴板实现（macOS / Android / iOS 等）。
Future<void> copyToClipboard(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
}
