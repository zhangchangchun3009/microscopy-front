import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/video/roi_overlay.dart';

void main() {
  group('RoiOverlay', () {
    testWidgets('支持创建并用新框覆盖旧框', (tester) async {
      RoiRectNorm? latestRoi;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 300,
                child: RoiOverlay(
                  imageSize: const Size(400, 200),
                  onRoiChanged: (roi) => latestRoi = roi,
                ),
              ),
            ),
          ),
        ),
      );

      final overlay = find.byType(RoiOverlay);
      await tester.dragFrom(
        tester.getCenter(overlay) + const Offset(-100, -50),
        const Offset(200, 100),
      );
      await tester.pump();

      expect(latestRoi, isNotNull);
      final first = latestRoi!;
      expect(first.x, inInclusiveRange(0.20, 0.35));
      expect(first.y, inInclusiveRange(0.20, 0.35));
      expect(first.w, inInclusiveRange(0.35, 0.60));
      expect(first.h, inInclusiveRange(0.35, 0.60));

      await tester.dragFrom(
        tester.getCenter(overlay) + const Offset(0, -30),
        const Offset(160, 100),
      );
      await tester.pump();

      expect(latestRoi!.x, greaterThanOrEqualTo(first.x));
      expect(latestRoi!.y, greaterThanOrEqualTo(first.y));
      expect(latestRoi!.w, inInclusiveRange(0.25, 0.55));
      expect(latestRoi!.h, inInclusiveRange(0.35, 0.65));
      expect(find.byKey(const ValueKey('roi-rect')), findsOneWidget);
    });

    testWidgets('选中态显示右侧清除按钮并可清空 ROI', (tester) async {
      RoiRectNorm? latestRoi;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: RoiOverlay(
                imageSize: const Size(400, 200),
                onRoiChanged: (roi) => latestRoi = roi,
              ),
            ),
          ),
        ),
      );

      final overlay = find.byType(RoiOverlay);
      await tester.dragFrom(
        tester.getCenter(overlay) + const Offset(-80, -40),
        const Offset(120, 80),
      );
      await tester.pump();
      expect(latestRoi, isNotNull);
      expect(find.byKey(const ValueKey('roi-clear-button')), findsNothing);

      await tester.tapAt(tester.getCenter(overlay));
      await tester.pump();
      expect(find.byKey(const ValueKey('roi-clear-button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('roi-clear-button')));
      await tester.pump();
      expect(latestRoi, isNull);
      expect(find.byKey(const ValueKey('roi-rect')), findsNothing);
    });

    testWidgets('选中后支持平移与角点缩放', (tester) async {
      RoiRectNorm? latestRoi;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: RoiOverlay(
                imageSize: const Size(400, 200),
                onRoiChanged: (roi) => latestRoi = roi,
              ),
            ),
          ),
        ),
      );

      final overlay = find.byType(RoiOverlay);
      await tester.dragFrom(
        tester.getCenter(overlay) + const Offset(-80, -50),
        const Offset(100, 80),
      );
      await tester.pump();

      await tester.tapAt(tester.getCenter(overlay) + const Offset(-30, -10));
      await tester.pump();

      await tester.dragFrom(
        tester.getCenter(overlay) + const Offset(-30, -10),
        const Offset(40, 20),
      );
      await tester.pump();

      final moved = latestRoi!;
      expect(moved.x, greaterThan(0.30));
      expect(moved.y, greaterThan(0.30));
      expect(moved.w, inInclusiveRange(0.18, 0.35));
      expect(moved.h, inInclusiveRange(0.28, 0.50));

      await tester.dragFrom(
        tester.getTopLeft(find.byKey(const ValueKey('roi-handle-tl'))) +
            const Offset(3, 3),
        const Offset(-20, -20),
      );
      await tester.pump();

      expect(latestRoi!.x, lessThanOrEqualTo(moved.x));
      expect(latestRoi!.y, lessThanOrEqualTo(moved.y));
      expect(latestRoi!.w, greaterThanOrEqualTo(moved.w));
      expect(latestRoi!.h, greaterThanOrEqualTo(moved.h));
    });
  });
}
