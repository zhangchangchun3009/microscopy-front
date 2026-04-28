import 'package:flutter/foundation.dart';

/// OTA 平台策略。
///
/// 当前 OTA 服务器上的 `flutter_app` 产物是 Android APK；Web 随 MicroClaw
/// 分发，macOS 暂按开发/调试入口处理，因此只有 Android 原生客户端参与 APK OTA。
class OtaPlatform {
  const OtaPlatform._();

  /// 返回当前运行平台是否支持 APK OTA 下载与安装。
  static bool currentSupportsApkOta() {
    return supportsApkOta(isWeb: kIsWeb, platform: defaultTargetPlatform);
  }

  /// 判断指定平台是否应参与 APK OTA。
  ///
  /// [isWeb] 表示当前是否为 Flutter Web；[platform] 是 Flutter 识别到的目标平台。
  /// 返回 true 仅表示这是 Android 原生客户端，不代表远端一定存在新版本。
  static bool supportsApkOta({
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    return !isWeb && platform == TargetPlatform.android;
  }

  /// 返回上报给 Agent 的稳定平台名。
  ///
  /// [isWeb] 为 true 时总是返回 `web`，避免浏览器宿主系统被误判为桌面 App。
  static String platformName({
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    if (isWeb) {
      return 'web';
    }
    return switch (platform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  /// 返回当前运行平台的稳定平台名。
  static String currentPlatformName() {
    return platformName(isWeb: kIsWeb, platform: defaultTargetPlatform);
  }
}
