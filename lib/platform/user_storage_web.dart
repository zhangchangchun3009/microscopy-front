import 'dart:js_interop';

@JS('window.localStorage.getItem')
external JSString? _getItem(JSString key);

@JS('window.localStorage.setItem')
external void _setItem(JSString key, JSString value);

@JS('window.localStorage.removeItem')
external void _removeItem(JSString key);

const _storageKey = 'microscope_app_config';

/// Web 平台的用户配置存储 — 基于 localStorage
Future<String?> readUserConfig() async {
  final result = _getItem(_storageKey.toJS);
  return result?.toDart;
}

Future<void> writeUserConfig(String json) async {
  _setItem(_storageKey.toJS, json.toJS);
}

Future<void> deleteUserConfig() async {
  _removeItem(_storageKey.toJS);
}

Future<String> userConfigPath() async {
  return 'localStorage[$_storageKey]';
}
