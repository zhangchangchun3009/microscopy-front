import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/video/scale_ruler_math.dart';

void main() {
  group('pickNiceLengthUm', () {
    test('matches web getNiceLengthGlobal for common targets', () {
      expect(pickNiceLengthUm(4.5), 5);
      expect(pickNiceLengthUm(45), 50);
      expect(pickNiceLengthUm(750), 500);
    });
  });

  group('computeRulerDisplay', () {
    test('returns positive ruler length for valid inputs', () {
      final a = computeRulerDisplay(
        pixelSizeUmPerPx: 0.9,
        magnification: 20,
        viewportScale: 1.0,
        containerWidthPx: 500,
      );
      expect(a, isNotNull);
      expect(a!.rulerLengthPx, greaterThan(0));
      expect(a.niceLengthUm, greaterThan(0));
    });

    test('matches script.js: 10μm/px @20×、800px 容器 → target 80μm → nice 100', () {
      final d = computeRulerDisplay(
        pixelSizeUmPerPx: 10,
        magnification: 20,
        viewportScale: 1,
        containerWidthPx: 800,
      );
      expect(d, isNotNull);
      expect(d!.niceLengthUm, 100);
    });

    test('容器变宽时 nice 档位单调不减', () {
      final narrow = computeRulerDisplay(
        pixelSizeUmPerPx: 10,
        magnification: 20,
        viewportScale: 1,
        containerWidthPx: 400,
      );
      final wide = computeRulerDisplay(
        pixelSizeUmPerPx: 10,
        magnification: 20,
        viewportScale: 1,
        containerWidthPx: 1200,
      );
      expect(narrow, isNotNull);
      expect(wide, isNotNull);
      expect(wide!.niceLengthUm >= narrow!.niceLengthUm, isTrue);
    });

    test('returns null when magnification is zero', () {
      expect(
        computeRulerDisplay(
          pixelSizeUmPerPx: 0.09,
          magnification: 0,
          viewportScale: 1,
          containerWidthPx: 400,
        ),
        isNull,
      );
    });
  });

  group('formatRulerLabel', () {
    test('uses mm when >= 1000 um', () {
      expect(formatRulerLabel(1500), '1.5 mm');
    });

    test('uses um for smaller lengths', () {
      expect(formatRulerLabel(50), '50 μm');
    });
  });
}
