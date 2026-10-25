import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:great_wall_ux/src/render/screen_exposure.dart';

void main() {
  const int maxIter = 1024;

  group('screenExposure', () {
    test('nothing escapes: no fit', () {
      final Uint32List counts = Uint32List(12)..fillRange(0, 12, maxIter);
      expect(screenExposure(counts, 4, 3, maxIter), isNull);
    });

    test('a flat screen sits at its count, at the minimum slope', () {
      final Uint32List counts = Uint32List(12)..fillRange(0, 12, 10);
      final ScreenExposure? e = screenExposure(counts, 4, 3, maxIter);
      expect(e!.h, 10.0);
      expect(e.s, kExposureMinSlope);
    });

    test('a ramp: quantiles interpolate like numpy.percentile', () {
      // 3 rows of 0..40 — every pixel smooth. Expected values from the film's
      // own `uxengine.exposure` on the same raster: (20.0, 9.0).
      const int w = 41;
      final Uint32List counts =
          Uint32List.fromList(<int>[for (int i = 0; i < 3 * w; i++) i % w]);
      final ScreenExposure? e = screenExposure(counts, w, 3, maxIter);
      expect(e!.h, closeTo(20.0, 1e-9));
      expect(e.s, closeTo(9.0, 1e-9));
    });

    test('matches the film on shells, filigree and an inside region', () {
      // Smooth shells, a noisy high-count patch (filigree: not smooth, so
      // excluded), and an inside-the-set corner. Expected values from the
      // film's `uxengine.exposure` on the same raster: (36.5, 9.25).
      const int w = 64;
      const int h = 48;
      int state = 12345;
      int lcg() => state = (1664525 * state + 1013904223) & 0xFFFFFFFF;
      final Uint32List counts = Uint32List(w * h);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          int n = 10 + (x + 2 * y) ~/ 3;
          if (x >= 40 && x < 56 && y >= 8 && y < 24) n = 200 + lcg() % 300;
          if (x < 6 && y < 6) n = maxIter;
          counts[y * w + x] = n;
        }
      }
      final ScreenExposure? e = screenExposure(counts, w, h, maxIter);
      expect(e!.h, closeTo(36.5, 1e-9));
      expect(e.s, closeTo(9.25, 1e-9));
    });

    test('falls back to every escaping pixel when none is smooth', () {
      // A checkerboard of 0 and 10: no pixel has neighbours within a count.
      final Uint32List counts = Uint32List.fromList(<int>[
        for (int y = 0; y < 4; y++)
          for (int x = 0; x < 4; x++) (x + y).isEven ? 0 : 10,
      ]);
      final ScreenExposure? e = screenExposure(counts, 4, 4, maxIter);
      expect(e!.h, closeTo(5.0, 1e-9));
    });
  });
}
