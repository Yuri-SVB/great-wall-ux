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

/// A canonical island to highlight, painted flat white.
///
/// Each entry of [pointsReIm] is a point of the island in fractal coordinates,
/// stored interleaved as `[re0, im0, re1, im1, ...]` (compact for the thousands
/// of points a single island can have). They are the cell centres the core's
/// discovery flood fill visited, on a lattice of [cellSize] fractal units
/// derived from the leaf rectangle (the island's `pixel_delta`).
///
/// The painter treats them as **seeds, not as the shape**. Escape count is a
/// property of a point rather than of the lattice that sampled it, so each one
/// stays a valid seed at any resolution; the canvas re-floods from them over the
/// raster it is drawing and paints that union, which stays crisp at every zoom
/// instead of fattening into `cellSize` blocks. [escapeCount] is the count that
/// defines the island's level set and is what the fill matches on — without it
/// the island can only be drawn as cells. See `island_fill.dart`.
///
/// The union of [cellSize] cells at [pointsReIm] remains the fallback shape, for
/// when the fill cannot resolve the island on the raster at hand.
@immutable
class CanvasIsland {
  const CanvasIsland({
    required this.cellSize,
    required this.pointsReIm,
    this.escapeCount = unknownEscapeCount,
  });

  /// Sentinel for "the host did not supply an escape count". Such an island is
  /// never flood-filled; it falls back to its cells.
  static const int unknownEscapeCount = -1;

  /// Discovery lattice spacing, in fractal units — the fallback cell side.
  final double cellSize;

  /// Interleaved `[re, im]` island points in fractal coordinates. Seeds for the
  /// fill; cell centres for the fallback.
  final List<double> pointsReIm;

  /// The escape count shared by every point of the island, or
  /// [unknownEscapeCount].
  final int escapeCount;

  /// Value equality, so a canvas can tell "the same islands, rebuilt" from "new
  /// islands" and re-run the flood fill only for the latter. [listEquals] is
  /// identity-first, so the common case (a host rebuilding its overlay list
  /// around the same island objects) costs a pointer comparison rather than a
  /// walk over thousands of points.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasIsland &&
          other.cellSize == cellSize &&
          other.escapeCount == escapeCount &&
          listEquals(other.pointsReIm, pointsReIm);

  /// Deliberately excludes the point values: they are the expensive part, and
  /// hashing on the fields that are necessarily equal for equal islands keeps
  /// this O(1).
  @override
  int get hashCode => Object.hash(cellSize, escapeCount, pointsReIm.length);
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

/// A set of cells on a regular grid in fractal coordinates: one byte per cell,
/// non-zero for a cell of the set, row-major from the lowest imaginary part.
@immutable
class CanvasCells {
  const CanvasCells({
    required this.originRe,
    required this.originIm,
    required this.cellSize,
    required this.width,
    required this.height,
    required this.cells,
  });

  /// Centre of cell `(0, 0)`, in fractal coordinates.
  final double originRe;
  final double originIm;

  /// Cell side, in fractal units.
  final double cellSize;
  final int width;
  final int height;

  /// `width × height` bytes.
  final Uint8List cells;

  /// Whether the fractal point `(re, im)` lies in one of the cells.
  bool contains(double re, double im) {
    final int x = ((re - originRe) / cellSize + 0.5).floor();
    final int y = ((im - originIm) / cellSize + 0.5).floor();
    return x >= 0 && y >= 0 && x < width && y < height && cells[y * width + x] != 0;
  }
}

/// One stop of a [CanvasPath]: its centre and the feature to highlight.
///
/// With a count range, the highlight is flood filled over the raster on screen
/// from the feature's cells, through pixels whose escape count lies in
/// `[countLow, countHigh]`, so it stays crisp at every zoom (an island with its
/// shells). Without one, or where the fill cannot resolve it (the range
/// reaches the render cap, or the feature is sub-pixel), the cells themselves
/// are drawn (the outer shell, a fiord).
@immutable
class CanvasPathStop {
  const CanvasPathStop({
    required this.re,
    required this.im,
    required this.cells,
    this.countLow,
    this.countHigh,
  });

  /// The stop's centre (its feature's barycentre), in fractal coordinates.
  final double re;
  final double im;
  final CanvasCells cells;
  final int? countLow;
  final int? countHigh;
}

/// Default stroke width of a path's line, in screen pixels.
const double kPathLineWidthPx = 2.0;

/// Default radius of a path's numbered stop markers, in screen pixels.
const double kPathStopRadiusPx = 9.0;

/// Default font size of a stop's number, in screen pixels.
const double kPathLabelSizePx = 11.0;

/// Default opacity of a path's feature highlights: translucent, so the
/// fractal stays visible beneath them.
const double kPathHighlightOpacity = 0.45;

/// A landmark path: a line through its stops' centres, each stop numbered
/// from 1, and each stop's feature highlighted.
///
/// Compared by identity: a host keeps one object per path, and the canvas
/// re-fills the highlights only when it changes.
@immutable
class CanvasPath {
  const CanvasPath({
    required this.stops,
    this.colour = const Color(0xFFFFFFFF),
    this.labelColour = const Color(0xFF000000),
    this.lineWidthPx = kPathLineWidthPx,
    this.stopRadiusPx = kPathStopRadiusPx,
    this.labelSizePx = kPathLabelSizePx,
    this.highlightOpacity = kPathHighlightOpacity,
  });

  final List<CanvasPathStop> stops;

  /// Colour of the line, the stop markers and the highlights.
  final Color colour;

  /// Colour of the stop numbers, on the markers.
  final Color labelColour;
  final double lineWidthPx;
  final double stopRadiusPx;
  final double labelSizePx;
  final double highlightOpacity;
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
    this.path,
  });

  final List<PointMarker> points;
  final bool crosshairs;

  /// Bisection rectangles. Painted only when the canvas is in debug mode.
  /// Outside debug mode they are silently dropped — the gating is enforced
  /// at the painter, not the caller.
  final List<BisectionRect> bisectionRects;

  /// Canonical islands to highlight (flat white). Empty unless the host has
  /// enumerated them (e.g. the Setup screen's `E` action).
  ///
  /// The canvas re-derives each island's shape at the current render
  /// resolution by flood filling from its points, so the host supplies the
  /// island once and it stays crisp through pan and zoom without being
  /// recomputed. See [CanvasIsland].
  final List<CanvasIsland> islands;

  /// Selection frames drawn around chosen islands.
  final List<SelectionFrame> frames;

  /// Fixed-size cross markers (e.g. the generated point's canonical island).
  final List<CrossMarker> crosses;

  /// A landmark path to draw, or null for none.
  final CanvasPath? path;

  static const CanvasOverlays empty = CanvasOverlays();
}
