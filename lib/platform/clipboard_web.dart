// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_interop';

/// Web 平台剪贴板实现 — 直接调用浏览器 Clipboard API。
///
/// 绕过 Flutter 的 [Clipboard.setData]（通过 SystemChannel 间接调用，
/// 在某些浏览器环境下静默失败），改用 `navigator.clipboard.writeText()`。
/// 当 Clipboard API 不可用时，回退到隐藏 textarea + execCommand 方案。
@JS('navigator.clipboard.writeText')
external JSPromise<JSAny?> _clipboardWriteText(JSString text);

Future<void> copyToClipboard(String text) async {
  // 1. 优先使用现代 Clipboard API
  try {
    await _clipboardWriteText(text.toJS).toDart;
    return;
  } catch (_) {
    // Clipboard API 不可用（非安全上下文等），回退到 DOM 方案
  }

  // 2. 回退：隐藏 textarea + execCommand('copy')
  final textarea = html.TextAreaElement()
    ..value = text
    ..style.cssText = 'position:fixed;left:-9999px;top:-9999px;opacity:0';
  html.document.body!.append(textarea);
  textarea.select();
  html.document.execCommand('copy');
  textarea.remove();
}
