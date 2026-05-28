import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A point marker drawn on top of the fractal raster.
@immutable
class PointMarker {
  const PointMarker({
    required this.re,
    required this.im,
    this.colour = const Color(0xFFFFFFFF),
    this.radiusPx = 4.0,
  });
  final double re;
  final double im;
  final Color colour;
  final double radiusPx;
}

/// Debug-mode bisection-area rectangle.
///
/// Surfacing this overlay outside debug mode would teach the user explicit,
/// verbalizable facts whose memorisation undermines TKBA — see
/// `great-wall-docs/great-wall-ux/SCOPE.md` and the TKBA discussion in
/// `great-wallet/ARCHITECTURE.md`. The canvas widget only paints these when
/// `debugBisectionOverlay == true`.
@immutable
class BisectionRect {
  const BisectionRect({
    required this.reMin,
    required this.imMin,
    required this.reMax,
    required this.imMax,
  });
  final double reMin;
  final double imMin;
  final double reMax;
  final double imMax;
}

/// All overlays paintable on the canvas for one frame.
@immutable
class CanvasOverlays {
  const CanvasOverlays({
    this.points = const <PointMarker>[],
    this.crosshairs = false,
    this.bisectionRects = const <BisectionRect>[],
  });

  final List<PointMarker> points;
  final bool crosshairs;

  /// Bisection rectangles. Painted only when the canvas is in debug mode.
  /// Outside debug mode they are silently dropped — the gating is enforced
  /// at the painter, not the caller.
  final List<BisectionRect> bisectionRects;

  static const CanvasOverlays empty = CanvasOverlays();
}
