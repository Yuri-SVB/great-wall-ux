import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:great_wall_ux/great_wall_ux.dart';
import 'package:great_wall_ux/src/render/screen_exposure.dart';

/// Every pixel escapes at [count]: its screen exposure is h = count, s = the
/// minimum slope.
class _FlatSource implements EscapeCountSource {
  _FlatSource(this.count);
  final int count;

  @override
  Future<EscapeCountRaster> escapeCounts(EscapeCountRequest request) async {
    final int w = request.viewport.widthPx;
    final int h = request.viewport.heightPx;
    return EscapeCountRaster(
      widthPx: w,
      heightPx: h,
      maxIterations: request.maxIterations,
      counts: Uint32List(w * h)..fillRange(0, w * h, count),
    );
  }
}

void main() {
  const int count = 30;
  // At halfExtent = kReferenceHalfExtent the zoom is 1, so the offset that puts
  // half brightness at `count` is count − log2(B).
  final double targetOffset =
      count - math.log(kBrightnessFalloffBase) / math.ln2;

  Future<(BrightnessController, PanZoomController)> pumpCanvas(
    WidgetTester tester, {
    required bool auto,
  }) async {
    final BrightnessController brightness =
        BrightnessController(autoExposure: auto);
    final PanZoomController viewport = PanZoomController(
      initial: const FractalViewport(
        centreRe: 0,
        centreIm: 0,
        halfExtent: kReferenceHalfExtent,
        widthPx: 1,
        heightPx: 1,
        devicePixelRatio: 1,
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 64,
          height: 48,
          child: FractalCanvas(
            source: _FlatSource(count),
            controller: viewport,
            palette: Palette.green,
            stage: Stage.stage1,
            brightness: brightness,
            maxIterations: 64,
          ),
        ),
      ),
    );
    // `flutter test` does not bundle the package-qualified shader asset; the
    // canvas then paints black, which these tests do not look at. Any other
    // error still fails the test.
    void allowMissingShader() {
      final Object? error = tester.takeException();
      if (error != null) expect('$error', contains('fractal.frag'));
    }

    allowMissingShader();
    // Let the resize land, the rasters render and their images decode (real
    // async work).
    for (int i = 0; i < 4; i++) {
      await tester.pump();
      allowMissingShader();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    return (brightness, viewport);
  }

  // Run the ease to its end, a frame at a time.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i * 16 <= kAutoExposureEase.inMilliseconds + 16 * 2; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('auto exposure eases offset and slope to the screen fit',
      (WidgetTester tester) async {
    final (BrightnessController b, _) = await pumpCanvas(tester, auto: true);
    await settle(tester);
    expect(b.autoExposure, isTrue);
    expect(b.offset, closeTo(targetOffset, 1e-9));
    expect(b.slope, closeTo(kExposureMinSlope, 1e-9));
  });

  testWidgets('it eases rather than jumps', (WidgetTester tester) async {
    final (BrightnessController b, _) = await pumpCanvas(tester, auto: true);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      b.offset,
      isNot(closeTo(targetOffset, 1e-3)),
      reason: 'two frames in, the offset is still on its way',
    );
    expect(b.offset, isNot(kDefaultBrightnessOffset));
  });

  testWidgets('off: the values stay at the defaults',
      (WidgetTester tester) async {
    final (BrightnessController b, _) = await pumpCanvas(tester, auto: false);
    await settle(tester);
    expect(b.offset, kDefaultBrightnessOffset);
    expect(b.slope, kDefaultBrightnessSlope);
  });

  testWidgets('a manual nudge stops the easing where it was',
      (WidgetTester tester) async {
    final (BrightnessController b, _) = await pumpCanvas(tester, auto: true);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    b.adjustBySteps(1);
    final double nudged = b.offset;
    await settle(tester);
    expect(b.autoExposure, isFalse);
    expect(b.offset, nudged);
  });

  testWidgets('switching it on fits the raster already shown',
      (WidgetTester tester) async {
    final (BrightnessController b, _) = await pumpCanvas(tester, auto: false);
    b.autoExposure = true;
    await settle(tester);
    expect(b.offset, closeTo(targetOffset, 1e-9));
  });
}
