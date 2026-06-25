import 'viewport.dart';

/// Deterministic pixel ↔ fractal-coordinate mapping for a [FractalViewport].
///
/// This is the single point at which logical pixels and fractal coordinates
/// meet. The math here is bit-deterministic across platforms by
/// construction:
///
/// - No trigonometric or transcendental functions.
/// - No platform-dependent rounding modes are touched.
/// - All operations are pure IEEE-754 double-precision arithmetic in a
///   fixed order, identical on every target.
///
/// The bisection's pixel-to-coordinate contract relies on this property;
/// the determinism is verified by golden tests.
class ViewportMath {
  const ViewportMath(this.viewport);

  final FractalViewport viewport;

  /// Half-extent on the shorter axis, in fractal units.
  double get _halfShort => viewport.halfExtent;

  /// Pixel size of the shorter axis (in logical pixels).
  int get _shortPx =>
      viewport.widthPx < viewport.heightPx ? viewport.widthPx : viewport.heightPx;

  /// Fractal units per logical pixel. Equal on both axes (square pixels in
  /// fractal space).
  double get unitsPerPixel => (2.0 * _halfShort) / _shortPx;

  /// Convert a logical pixel `(px, py)` (origin top-left, +y down) to a
  /// fractal coordinate `(re, im)`.
  ///
  /// The pixel centre convention is "pixel `(px, py)` covers the open
  /// square `[px, px+1) × [py, py+1)` and its sample point is
  /// `(px + 0.5, py + 0.5)`". This matches the convention used by the
  /// `great-wall-core` raster path.
  (double, double) pixelToCoord(double px, double py) {
    final double u = unitsPerPixel;
    final double sx = px + 0.5 - viewport.widthPx / 2.0;
    final double sy = py + 0.5 - viewport.heightPx / 2.0;
    final double re = viewport.centreRe + sx * u;
    // The displayed raster (great-wall-core's escape-count buffer, drawn by the
    // canvas shader) has its imaginary axis increasing downward in screen
    // space. The coordinate mapping must match that exact orientation, or
    // overlays, pan, and zoom-to-cursor are vertically inverted relative to the
    // fractal the user sees. (This mapping is what drives markers and gestures;
    // it does NOT affect how the raster itself is drawn.)
    final double im = viewport.centreIm + sy * u;
    return (re, im);
  }

  /// Convert a fractal coordinate `(re, im)` to a logical pixel `(px, py)`.
  ///
  /// Returns the continuous pixel coordinate (not rounded). The inverse of
  /// [pixelToCoord] up to the per-pixel `+0.5` sample-centre offset.
  (double, double) coordToPixel(double re, double im) {
    final double u = unitsPerPixel;
    final double sx = (re - viewport.centreRe) / u;
    final double sy = (im - viewport.centreIm) / u;
    final double px = sx + viewport.widthPx / 2.0 - 0.5;
    final double py = sy + viewport.heightPx / 2.0 - 0.5;
    return (px, py);
  }
}
