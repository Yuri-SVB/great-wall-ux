import 'package:flutter_test/flutter_test.dart';
import 'package:great_wall_ux/great_wall_ux.dart';

void main() {
  group('ViewportMath', () {
    const FractalViewport vp = FractalViewport(
      centreRe: 0.0,
      centreIm: 0.0,
      halfExtent: 2.0,
      widthPx: 400,
      heightPx: 400,
      devicePixelRatio: 1.0,
    );

    test('centre pixel maps to centre coordinate', () {
      const ViewportMath m = ViewportMath(vp);
      final (double re, double im) = m.pixelToCoord(199.5, 199.5);
      expect(re, closeTo(0.0, 1e-12));
      expect(im, closeTo(0.0, 1e-12));
    });

    test('imaginary axis increases downward, matching the raster', () {
      // The coordinate mapping matches the displayed raster's orientation
      // (im increases downward in screen space), so overlays and gestures
      // align with the fractal. Top row has the smaller imaginary value.
      const ViewportMath m = ViewportMath(vp);
      final (_, double imTop) = m.pixelToCoord(199.5, 0.5);
      final (_, double imBot) = m.pixelToCoord(199.5, 399.5);
      expect(imTop, lessThan(imBot));
    });

    test('pixelToCoord and coordToPixel are inverses', () {
      const ViewportMath m = ViewportMath(vp);
      for (final (double px, double py) in <(double, double)>[
        (0.5, 0.5),
        (100.5, 50.5),
        (199.5, 199.5),
        (350.5, 380.5),
      ]) {
        final (double re, double im) = m.pixelToCoord(px, py);
        final (double rx, double ry) = m.coordToPixel(re, im);
        expect(rx, closeTo(px, 1e-9));
        expect(ry, closeTo(py, 1e-9));
      }
    });

    test('determinism: identical viewports → identical mappings', () {
      // Pixel-to-coordinate determinism is load-bearing; the same FractalViewport
      // value must produce bit-equal coords across every invocation.
      const ViewportMath a = ViewportMath(vp);
      const ViewportMath b = ViewportMath(vp);
      for (int i = 0; i < 32; i++) {
        final double p = i * 13.5;
        final (double r1, double i1) = a.pixelToCoord(p, p);
        final (double r2, double i2) = b.pixelToCoord(p, p);
        expect(r1, equals(r2));
        expect(i1, equals(i2));
      }
    });

    test('unitsPerPixel is square (depends on shorter axis only)', () {
      const FractalViewport wide = FractalViewport(
        centreRe: 0.0,
        centreIm: 0.0,
        halfExtent: 2.0,
        widthPx: 800,
        heightPx: 400,
        devicePixelRatio: 1.0,
      );
      const FractalViewport tall = FractalViewport(
        centreRe: 0.0,
        centreIm: 0.0,
        halfExtent: 2.0,
        widthPx: 400,
        heightPx: 800,
        devicePixelRatio: 1.0,
      );
      expect(
        const ViewportMath(wide).unitsPerPixel,
        equals(const ViewportMath(tall).unitsPerPixel),
      );
    });
  });

  group('PanZoomController', () {
    test('zoomBy preserves the focal coordinate', () {
      final PanZoomController c = PanZoomController(
        initial: const FractalViewport(
          centreRe: 0.5,
          centreIm: -0.3,
          halfExtent: 1.5,
          widthPx: 400,
          heightPx: 300,
          devicePixelRatio: 1.0,
        ),
      );
      const double fx = 123.4;
      const double fy = 87.6;
      final (double anchorRe, double anchorIm) =
          ViewportMath(c.viewport).pixelToCoord(fx, fy);
      c.zoomBy(2.0, fx: fx, fy: fy);
      final (double afterRe, double afterIm) =
          ViewportMath(c.viewport).pixelToCoord(fx, fy);
      expect(afterRe, closeTo(anchorRe, 1e-9));
      expect(afterIm, closeTo(anchorIm, 1e-9));
    });
  });
}
