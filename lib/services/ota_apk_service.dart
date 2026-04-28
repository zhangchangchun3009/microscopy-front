import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'ota_platform.dart';

/// OTA APK 下载 + SHA256 校验 + 安装服务。
///
/// Android: 检查安装权限 → 下载 APK → 校验 → 触发系统安装对话框。
/// Web/macOS/其他平台: 不参与 APK OTA，避免误下载 Android 安装包。
class OtaApkService {
  static final OtaApkService _instance = OtaApkService._();
  factory OtaApkService() => _instance;
  OtaApkService._();

  static const _channel = MethodChannel('com.yingxi.microscope_app/ota');

  bool _downloading = false;
  bool get isDownloading => _downloading;

  /// 下载进度回调 (0.0 ~ 1.0)
  void Function(double progress)? onProgress;

  /// 下载/安装结果回调
  void Function(OtaApkResult result)? onResult;

  /// 因权限不足暂存的下载参数，授权后可自动恢复。
  _PendingDownload? _pendingDownload;

  /// 是否有因权限不足而暂存的下载任务。
  bool get hasPendingDownload => _pendingDownload != null;

  /// 授权后调用：使用暂存参数重试下载。
  ///
  /// 返回 true 表示成功启动下载，false 表示无暂存任务。
  Future<bool> retryPendingDownload() async {
    final pending = _pendingDownload;
    if (pending == null) return false;
    _pendingDownload = null;
    await startDownload(
      url: pending.url,
      sha256: pending.sha256,
      version: pending.version,
      fileSize: pending.fileSize,
      authHeaders: pending.authHeaders,
    );
    return true;
  }

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
    Map<String, String>? authHeaders,
  }) async {
    if (!OtaPlatform.currentSupportsApkOta()) {
      debugPrint(
        '[OTA] 当前平台 ${OtaPlatform.currentPlatformName()} 不参与 APK OTA，忽略 v$version',
      );
      return;
    }

    if (_downloading) {
      debugPrint('[OTA] 下载已在进行中，忽略重复请求');
      return;
    }

    // 0. Android: 检查安装权限（下载前检查，避免白下载）
    try {
      final canInstall =
          await _channel.invokeMethod<bool>('checkInstallPermission') ?? false;
      if (!canInstall) {
        debugPrint('[OTA] 缺少安装权限，暂存下载参数');
        _pendingDownload = _PendingDownload(
          url: url,
          sha256: sha256,
          version: version,
          fileSize: fileSize,
          authHeaders: authHeaders,
        );
        onResult?.call(
          OtaApkResult(
            state: OtaApkState.needInstallPermission,
            version: version,
            message: '请在弹出的设置页面中允许本应用安装其他应用，授权后返回即可自动继续',
          ),
        );
        return;
      }
    } on PlatformException catch (e) {
      debugPrint('[OTA] 检查安装权限失败: ${e.message}');
      // 权限检查失败不阻断流程，继续下载
    }

    _downloading = true;
    onResult?.call(
      OtaApkResult(state: OtaApkState.downloading, version: version),
    );

    try {
      // 1. 下载 APK 到 applicationSupportDirectory（匹配 FileProvider files-path）
      final dir = await getApplicationSupportDirectory();
      final filePath = '${dir.path}/ota_update_$version.apk';
      final file = File(filePath);

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 3600),
          headers: {'User-Agent': 'MicroscopeApp/OTA', ...?authHeaders},
        ),
      );

      final dlStopwatch = Stopwatch()..start();
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress?.call(received / total);
          }
        },
      );
      dlStopwatch.stop();
      debugPrint(
        '[OTA] 下载完成，耗时 ${dlStopwatch.elapsedMilliseconds}ms，文件大小: ${file.lengthSync()} bytes',
      );

      // 2. SHA256 校验（纯本地计算，无网络流量）
      final hashStopwatch = Stopwatch()..start();
      final actualSha256 = await _sha256File(file);
      hashStopwatch.stop();
      debugPrint('[OTA] SHA256 校验耗时 ${hashStopwatch.elapsedMilliseconds}ms');

      if (actualSha256 != sha256.toLowerCase()) {
        debugPrint('[OTA] SHA256 校验失败: expected=$sha256 actual=$actualSha256');
        await file.delete();
        _downloading = false;
        onResult?.call(
          OtaApkResult(state: OtaApkState.checksumFailed, version: version),
        );
        return;
      }

      debugPrint('[OTA] SHA256 校验通过');

      // 3. Android: 触发系统安装
      await _installAndroid(file);
      onResult?.call(
        OtaApkResult(state: OtaApkState.installPrompt, version: version),
      );
    } on PlatformException catch (e) {
      debugPrint('[OTA] 安装失败: ${e.code} ${e.message}');
      onResult?.call(
        OtaApkResult(
          state: OtaApkState.downloadFailed,
          version: version,
          message: '安装失败: ${e.message}',
        ),
      );
    } catch (e) {
      debugPrint('[OTA] 下载失败: $e');
      onResult?.call(
        OtaApkResult(
          state: OtaApkState.downloadFailed,
          version: version,
          message: '下载失败: $e',
        ),
      );
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
  /// 通过 MethodChannel 调用原生安装。
  Future<void> _installAndroid(File apkFile) async {
    debugPrint('[OTA] 触发 Android 安装: ${apkFile.path}');
    await _channel.invokeMethod('installApk', {'filePath': apkFile.path});
  }
}

/// 暂存的下载参数（权限不足时保存，授权后恢复）。
class _PendingDownload {
  final String url;
  final String sha256;
  final String version;
  final int fileSize;
  final Map<String, String>? authHeaders;

  const _PendingDownload({
    required this.url,
    required this.sha256,
    required this.version,
    required this.fileSize,
    this.authHeaders,
  });
}

/// OTA APK 下载/安装状态。
enum OtaApkState {
  downloading, // 下载中
  downloaded, // 下载完成（非 Android 平台）
  installPrompt, // 已弹出安装对话框（Android）
  needInstallPermission, // 需要用户授权安装权限（Android 8+）
  checksumFailed, // SHA256 校验失败
  downloadFailed, // 下载失败
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
