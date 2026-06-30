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

/// A canonical island to highlight, as a set of equal-sized square cells.
///
/// Each entry of [pointsReIm] is a cell *centre* in fractal coordinates, stored
/// interleaved as `[re0, im0, re1, im1, ...]` (compact for the thousands of
/// cells a single island can have). Every cell is [cellSize] fractal units on a
/// side ([the island's `pixel_delta`]); the union of the cells is the island's
/// shape. The painter fills them flat white.
@immutable
class CanvasIsland {
  const CanvasIsland({required this.cellSize, required this.pointsReIm});

  /// Cell side length, in fractal units.
  final double cellSize;

  /// Interleaved `[re, im]` cell centres in fractal coordinates.
  final List<double> pointsReIm;
}

/// A fixed-size cross marker at a fractal coordinate. Unlike island cells (which
/// scale with zoom), the cross stays the same pixel size at every zoom, so it
/// always marks the spot; zoom in far enough and the island it sits on grows
/// into view around it.
@immutable
class CrossMarker {
  const CrossMarker({
    required this.re,
    required this.im,
    this.sizePx = 14.0,
    this.thicknessPx = 2.0,
    this.colour = const Color(0xFFFFFFFF),
  });

  final double re;
  final double im;

  /// Full arm-to-arm length of the cross, in screen pixels.
  final double sizePx;
  final double thicknessPx;
  final Color colour;
}

/// A selection frame: an axis-aligned white rectangle drawn *around* a region
/// (a canonical island's bounding box, in fractal coordinates), padded outward
/// by [paddingPx] screen pixels so the island sits comfortably inside it. Marks
/// the region as "selected".
@immutable
class SelectionFrame {
  const SelectionFrame({
    required this.reMin,
    required this.reMax,
    required this.imMin,
    required this.imMax,
    this.paddingPx = 10.0,
    this.thicknessPx = 2.0,
    this.colour = const Color(0xFFFFFFFF),
  });

  /// Bounding box of the framed region, in fractal coordinates.
  final double reMin;
  final double reMax;
  final double imMin;
  final double imMax;

  /// Outward padding from the box to the frame, in screen pixels.
  final double paddingPx;

  /// Stroke width of the frame, in screen pixels.
  final double thicknessPx;
  final Color colour;
}

/// All overlays paintable on the canvas for one frame.
@immutable
class CanvasOverlays {
  const CanvasOverlays({
    this.points = const <PointMarker>[],
    this.crosshairs = false,
    this.bisectionRects = const <BisectionRect>[],
    this.islands = const <CanvasIsland>[],
    this.frames = const <SelectionFrame>[],
    this.crosses = const <CrossMarker>[],
  });

  final List<PointMarker> points;
  final bool crosshairs;

  /// Bisection rectangles. Painted only when the canvas is in debug mode.
  /// Outside debug mode they are silently dropped — the gating is enforced
  /// at the painter, not the caller.
  final List<BisectionRect> bisectionRects;

  /// Canonical islands to highlight (flat white). Empty unless the host has
  /// enumerated them (e.g. the Setup screen's `E` action).
  final List<CanvasIsland> islands;

  /// Selection frames drawn around chosen islands.
  final List<SelectionFrame> frames;

  /// Fixed-size cross markers (e.g. the generated point's canonical island).
  final List<CrossMarker> crosses;

  static const CanvasOverlays empty = CanvasOverlays();
}
