import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/video/roi_overlay.dart';
import 'package:microscope_app/ui/video/video_stage.dart';

void main() {
  test('appendLiveSessionNonce 为视频地址附加/覆盖 _live 参数', () {
    final withNonce = VideoStage.appendLiveSessionNonce(
      'http://127.0.0.1:42617/video_feed',
      3,
    );
    expect(withNonce, 'http://127.0.0.1:42617/video_feed?_live=3');

    final merged = VideoStage.appendLiveSessionNonce(
      'http://127.0.0.1:42617/video_feed?foo=bar&_live=1',
      9,
    );
    expect(merged, 'http://127.0.0.1:42617/video_feed?foo=bar&_live=9');
  });

  testWidgets('滚轮缩放在 ROI 层之上生效，scale>1 时隐藏 ROI', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 700,
            child: VideoStage(
              videoUrl: 'http://127.0.0.1/x',
              isVideoLive: false,
              onToggleLive: () {},
              onRoiChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RoiOverlay), findsOneWidget);

    final stageRect = tester.getRect(find.byKey(const ValueKey('video-stage')));
    final target = Offset(stageRect.center.dx, stageRect.center.dy);

    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        timeStamp: Duration.zero,
        device: 1,
        position: target,
        scrollDelta: const Offset(0, -200),
      ),
    );
    await tester.pump();

    expect(find.byType(RoiOverlay), findsNothing);
  });
}
