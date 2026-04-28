import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/services/ota_platform.dart';

void main() {
  group('OtaPlatform', () {
    test('只有 Android 原生客户端参与 APK OTA', () {
      expect(
        OtaPlatform.supportsApkOta(
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        isTrue,
      );
      expect(
        OtaPlatform.supportsApkOta(
          isWeb: true,
          platform: TargetPlatform.android,
        ),
        isFalse,
      );
      expect(
        OtaPlatform.supportsApkOta(
          isWeb: false,
          platform: TargetPlatform.macOS,
        ),
        isFalse,
      );
    });

    test('上报给 Agent 的平台名稳定且可用于服务端判断', () {
      expect(
        OtaPlatform.platformName(isWeb: true, platform: TargetPlatform.macOS),
        'web',
      );
      expect(
        OtaPlatform.platformName(
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        'android',
      );
      expect(
        OtaPlatform.platformName(isWeb: false, platform: TargetPlatform.macOS),
        'macos',
      );
    });
  });
}
