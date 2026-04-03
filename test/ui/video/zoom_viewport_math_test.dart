import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/video/zoom_viewport_math.dart';

void main() {
  group('zoomAtPoint', () {
    test('no-op when newScale equals oldScale', () {
      final r = zoomAtPoint(
        oldScale: 2,
        oldPosX: 5,
        oldPosY: -3,
        newScale: 2,
        containerW: 400,
        containerH: 300,
        pointerLocalX: 100,
        pointerLocalY: 80,
      );
      expect(r.scale, 2);
      expect(r.posX, 5);
      expect(r.posY, -3);
    });

    test('clamps newScale to 1..5', () {
      final r = zoomAtPoint(
        oldScale: 4.5,
        oldPosX: 0,
        oldPosY: 0,
        newScale: 10,
        containerW: 400,
        containerH: 300,
        pointerLocalX: 200,
        pointerLocalY: 150,
      );
      expect(r.scale, 5.0);
    });
  });

  group('clampPan', () {
    test('zeros pan when scale <= 1', () {
      final r = clampPan(
        scale: 1,
        posX: 10,
        posY: -5,
        containerW: 400,
        containerH: 300,
        contentW: 320,
        contentH: 240,
      );
      expect(r.posX, 0);
      expect(r.posY, 0);
    });

    test('keeps pan within bounds when zoomed', () {
      final r = clampPan(
        scale: 2,
        posX: 1e6,
        posY: -1e6,
        containerW: 400,
        containerH: 300,
        contentW: 320,
        contentH: 240,
      );
      expect(r.posX.isFinite, isTrue);
      expect(r.posY.isFinite, isTrue);
      expect(r.scale, 2);
    });
  });
}
