import 'package:flutter/foundation.dart';

import '../canvas/viewport.dart';
import '../canvas/viewport_math.dart';

/// Mutable viewport state with pan/zoom convenience operations.
///
/// The controller is the source of viewport truth for the canvas widget.
/// All transforms preserve the pixel-to-coordinate determinism contract by
/// going through `FractalViewport` values (no hidden state).
class PanZoomController extends ChangeNotifier {
  PanZoomController({required FractalViewport initial}) : _viewport = initial;

  FractalViewport _viewport;
  FractalViewport get viewport => _viewport;
  set viewport(FractalViewport next) {
    if (next == _viewport) return;
    _viewport = next;
    notifyListeners();
  }

  /// Pan by `(dx, dy)` logical pixels (positive `dx` moves the view right).
  void panByPixels(double dx, double dy) {
    final double u = ViewportMath(_viewport).unitsPerPixel;
    viewport = _viewport.copyWith(
      centreRe: _viewport.centreRe - dx * u,
      centreIm: _viewport.centreIm + dy * u,
    );
  }

  /// Zoom by `factor` (`> 1` zooms in) around the logical pixel `(fx, fy)`.
  /// The focal pixel stays on the same fractal coordinate before and after.
  void zoomBy(double factor, {required double fx, required double fy}) {
    if (factor <= 0) throw ArgumentError.value(factor, 'factor', 'must be > 0');
    final ViewportMath before = ViewportMath(_viewport);
    final (double anchorRe, double anchorIm) = before.pixelToCoord(fx, fy);
    final FractalViewport scaled = _viewport.copyWith(
      halfExtent: _viewport.halfExtent / factor,
    );
    final ViewportMath after = ViewportMath(scaled);
    final (double afterRe, double afterIm) = after.pixelToCoord(fx, fy);
    viewport = scaled.copyWith(
      centreRe: scaled.centreRe + (anchorRe - afterRe),
      centreIm: scaled.centreIm + (anchorIm - afterIm),
    );
  }

  /// Recentre the view on the given fractal coordinate without changing
  /// zoom or surface size. Useful for "go to the point I clicked".
  void centreOn(double re, double im) {
    viewport = _viewport.copyWith(centreRe: re, centreIm: im);
  }

  /// React to a surface resize. Pure pixel resize — does not move the
  /// centre or change zoom.
  void resize({required int widthPx, required int heightPx, double? dpr}) {
    viewport = _viewport.copyWith(
      widthPx: widthPx,
      heightPx: heightPx,
      devicePixelRatio: dpr ?? _viewport.devicePixelRatio,
    );
  }
}
