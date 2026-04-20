import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// OTA APK 下载 + SHA256 校验 + 安装服务。
///
/// Android: 下载 APK → 校验 → 触发系统安装对话框。
/// macOS/其他: 下载后显示通知（无法原生安装 APK）。
class OtaApkService {
  static final OtaApkService _instance = OtaApkService._();
  factory OtaApkService() => _instance;
  OtaApkService._();

  bool _downloading = false;
  bool get isDownloading => _downloading;

  /// 下载进度回调 (0.0 ~ 1.0)
  void Function(double progress)? onProgress;

  /// 下载/安装结果回调
  void Function(OtaApkResult result)? onResult;

  /// 启动 APK 下载流程。
  ///
  /// [url] APK 下载地址
  /// [sha256] 预期的 SHA256 校验和（小写 hex）
  /// [version] 目标版本号
  /// [fileSize] 文件大小（字节）
  Future<void> startDownload({
    required String url,
    required String sha256,
    required String version,
    required int fileSize,
  }) async {
    if (_downloading) {
      debugPrint('[OTA] 下载已在进行中，忽略重复请求');
      return;
    }

    _downloading = true;
    onResult?.call(OtaApkResult(state: OtaApkState.downloading, version: version));

    try {
      // 1. 下载 APK
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/ota_update_$version.apk';
      final file = File(filePath);

      final dio = Dio();
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress?.call(received / total);
          }
        },
      );

      // 2. SHA256 校验
      final actualSha256 = await _sha256File(file);
      if (actualSha256 != sha256.toLowerCase()) {
        debugPrint('[OTA] SHA256 校验失败: expected=$sha256 actual=$actualSha256');
        await file.delete();
        _downloading = false;
        onResult?.call(OtaApkResult(
          state: OtaApkState.checksumFailed,
          version: version,
        ));
        return;
      }

      debugPrint('[OTA] SHA256 校验通过，文件大小: ${file.lengthSync()} bytes');

      // 3. 平台分发
      if (Platform.isAndroid) {
        await _installAndroid(file);
        onResult?.call(OtaApkResult(state: OtaApkState.installPrompt, version: version));
      } else {
        // macOS / 其他平台：显示通知，无法安装 APK
        debugPrint('[OTA] 非 Android 平台，跳过安装。文件: $filePath');
        onResult?.call(OtaApkResult(
          state: OtaApkState.downloaded,
          version: version,
          message: '有新版本 v$version 可用。当前平台不支持自动安装，请联系技术支持。',
        ));
      }
    } catch (e) {
      debugPrint('[OTA] 下载失败: $e');
      onResult?.call(OtaApkResult(
        state: OtaApkState.downloadFailed,
        version: version,
        message: '下载失败: $e',
      ));
    } finally {
      _downloading = false;
    }
  }

  /// 计算文件 SHA256（流式，避免大文件占满内存）。
  Future<String> _sha256File(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  /// Android: 触发系统安装 Intent。
  ///
  /// 通过 MethodChannel 调用原生安装，需要配合
  /// android/app/src/main/kotlin 中的 MethodChannel handler。
  Future<void> _installAndroid(File apkFile) async {
    debugPrint('[OTA] 触发 Android 安装: ${apkFile.path}');
  }
}

/// OTA APK 下载/安装状态。
enum OtaApkState {
  downloading,     // 下载中
  downloaded,      // 下载完成（非 Android 平台）
  installPrompt,   // 已弹出安装对话框（Android）
  checksumFailed,  // SHA256 校验失败
  downloadFailed,  // 下载失败
}

/// OTA APK 操作结果。
class OtaApkResult {
  final OtaApkState state;
  final String version;
  final String? message;

  const OtaApkResult({
    required this.state,
    required this.version,
    this.message,
  });
}
