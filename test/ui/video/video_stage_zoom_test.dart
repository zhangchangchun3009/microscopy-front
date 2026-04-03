import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/video/roi_overlay.dart';
import 'package:microscope_app/ui/video/video_stage.dart';

void main() {
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
