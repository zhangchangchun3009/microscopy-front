// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';


/// Web 端 MJPEG 视频源实现。
///
/// 在 Flutter Web 平台视图中创建 `<img>` 元素，使视频层随 Flutter
/// 布局、裁剪和变换移动，避免脱离 Flutter 树的 fixed DOM 覆盖弹窗、
/// ROI 或其他交互层。
class MjpegWebWidget extends StatefulWidget {
  final String videoUrl;
  final Widget Function(BuildContext, dynamic, dynamic)? errorBuilder;

  const MjpegWebWidget({super.key, required this.videoUrl, this.errorBuilder});

  @override
  State<MjpegWebWidget> createState() => _MjpegWebWidgetState();
}

class _MjpegWebWidgetState extends State<MjpegWebWidget> {
  static int _nextViewId = 0;

  late final String _viewType;
  html.Element? _host;
  html.ImageElement? _img;

  @override
  void initState() {
    super.initState();
    _viewType = 'mjpeg-web-view-${_nextViewId++}';
    _mount();
  }

  @override
  void didUpdateWidget(covariant MjpegWebWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _updateSrc(widget.videoUrl);
    }
  }

  void _mount() {
    final img = html.ImageElement()
      ..src = widget.videoUrl
      ..id = 'mjpeg-web-img-$_viewType'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain'
      ..style.display = 'block';
    _img = img;

    if (widget.errorBuilder != null) {
      img.onError.listen((_) {
        final host = _host;
        if (host != null) {
          host.innerHtml =
              '<p style="color:red;text-align:center;padding:12px">视频连接失败</p>';
        }
      });
    }

    _host = html.DivElement()
      ..id = 'mjpeg-web-host-$_viewType'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.pointerEvents = 'none'
      ..style.overflow = 'hidden'
      ..children.add(img);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _host!);
  }

  void _updateSrc(String url) {
    _img?.src = url;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(child: HtmlElementView(viewType: _viewType));
  }

  @override
  void dispose() {
    _img = null;
    _host = null;
    super.dispose();
  }
}

Widget buildMjpegView({
  required String videoUrl,
  Widget Function(BuildContext, dynamic, dynamic)? errorBuilder,
}) {
  return MjpegWebWidget(
    key: ValueKey(videoUrl),
    videoUrl: videoUrl,
    errorBuilder: errorBuilder,
  );
}
