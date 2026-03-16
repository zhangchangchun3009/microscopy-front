import 'package:socket_io_client/socket_io_client.dart' as io;

/// 与 microscopy_server 的 Socket.IO 连接。
///
/// 用途：
/// 1. 启动时连接后 emit('get_settings')，使后端应用相机/LED 等设置，MJPEG 流才能正常显示；
/// 2. 后续可复用同一连接接收长任务进度：global_scan_progress、stitch_progress、
///    focus_stack_progress、auto_brightness_progress、log_message 等，便于迁移原 Web 前端逻辑。
class MicroscopySocket {
  MicroscopySocket();

  io.Socket? _socket;
  bool _connecting = false;

  /// 是否已连接
  bool get isConnected => _socket?.connected ?? false;

  /// 连接并执行与 Web 前端一致的初始化：连接成功后 emit('get_settings')，
  /// 后端会应用 settings.json 中的曝光、增益、LED 等，视频流才能正常亮。
  ///
  /// [baseUrl] 为显微镜服务根地址，例如 http://10.198.31.242:5000
  void connect(String baseUrl) {
    if (_socket != null || _connecting) return;
    _connecting = true;
    final uri = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    _socket = io.io(
      uri,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _connecting = false;
      _socket!.emit('get_settings');
    });

    _socket!.onConnectError((data) {
      _connecting = false;
    });

    _socket!.onDisconnect((_) {});

    _socket!.connect();
  }

  /// 断开连接
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connecting = false;
  }

  /// 发送事件（与 Web 前端一致，便于迁移）
  void emit(String event, [dynamic data]) {
    if (data != null) {
      _socket?.emit(event, data);
    } else {
      _socket?.emit(event);
    }
  }

  /// 订阅服务端推送事件，用于进度条、日志等。返回取消订阅的函数。
  void Function() on(String event, void Function(dynamic) handler) {
    _socket?.on(event, handler);
    return () {
      _socket?.off(event);
    };
  }
}
