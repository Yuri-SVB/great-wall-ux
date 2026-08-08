import 'dart:typed_data';

import 'escape_count_source.dart';
import 'overlay.dart';
import 'viewport.dart';
import 'viewport_math.dart';

/// Resolution-independent rendering of a canonical island.
///
/// A canonical island is a *connected region of equal escape count*. The core
/// discovers it by flood-filling on a lattice derived from the leaf rectangle
/// (`min_grid_cells` cells across the leaf), and reports the cell centres it
/// visited. Drawing those cells as squares pins the island's apparent resolution
/// to the lattice the discovery happened to use: zoom past that and every cell
/// becomes a block, and a leaf whose island is one or two cells wide renders as
/// one or two specks.
///
/// The cell centres are exact coordinates, though, and escape count is a
/// property of a *point*, not of the lattice that sampled it. So every reported
/// point is still a valid seed at any other resolution. This library re-derives
/// the shape at the resolution actually on screen: seed a flood fill at each of
/// the island's points and take the union of the fills. That union is the
/// island's pixel set for this view — crisp at every zoom, and by construction
/// it can never disagree with the fractal underneath it, because it is filled
/// over the very raster being drawn.
///
/// No fractal arithmetic happens here. The escape counts are the ones
/// `great-wall-core` computed for this view (see [EscapeCountSource]); this is
/// segmentation of a raster the core produced, which is why it belongs to the
/// rendering layer rather than to the engine.

/// The pixel set of one or more canonical islands over a single raster.
///
/// [mask] is a row-major `widthPx * heightPx` coverage buffer parallel to the
/// raster: `255` for a pixel belonging to some island, `0` otherwise. [unfilled]
/// carries the islands the fill could not resolve on this raster (see
/// [fillIslands]); a caller should fall back to drawing those as discovery
/// cells so an island is never silently dropped.
class IslandFillResult {
  const IslandFillResult({
    required this.mask,
    required this.widthPx,
    required this.heightPx,
    required this.filledPixels,
    required this.unfilled,
  });

  final Uint8List mask;
  final int widthPx;
  final int heightPx;

  /// Total pixels covered across all islands.
  final int filledPixels;

  /// Islands that produced no pixels on this raster.
  final List<CanvasIsland> unfilled;

  /// Whether any island resolved into pixels.
  bool get isEmpty => filledPixels == 0;
}

/// Flood-fill every island of [islands] over [raster] and return their combined
/// pixel set.
///
/// [rasterViewport] must be the viewport the raster was rendered for — not
/// necessarily the viewport currently on screen, since the canvas renders a
/// reduced-resolution raster first and refines afterwards. It fixes the
/// coordinate↔pixel mapping used to place the seeds.
///
/// An island lands in [IslandFillResult.unfilled] when it cannot be resolved
/// here, which happens for two legitimate reasons:
///
///  - **The raster's iteration cap is too low.** Islands deep in the bisection
///    tree sit where escape counts climb toward the encoder's cap; rendered
///    under a lower cap their pixels do not escape at all and read as the
///    non-escaping sentinel, indistinguishable from the surrounding void. The
///    `escapeCount >= maxIterations` guard below rejects exactly that case —
///    without it, an island whose count collided with the sentinel would flood
///    the whole void white.
///  - **The island is sub-pixel here.** Every seed falls in a pixel whose
///    *centre* has a different escape count, so no seed takes. The region is
///    real but thinner than the sample grid; it resolves as you zoom in.
IslandFillResult fillIslands({
  required EscapeCountRaster raster,
  required FractalViewport rasterViewport,
  required List<CanvasIsland> islands,
}) {
  final int w = raster.widthPx;
  final int h = raster.heightPx;
  final Uint8List mask = Uint8List(w * h);
  final List<CanvasIsland> unfilled = <CanvasIsland>[];
  if (islands.isEmpty) {
    return IslandFillResult(
      mask: mask,
      widthPx: w,
      heightPx: h,
      filledPixels: 0,
      unfilled: unfilled,
    );
  }

  final ViewportMath math = ViewportMath(rasterViewport);
  // One stack for the whole pass: an index is pushed only when it is marked, so
  // it can hold at most every pixel once.
  final Uint32List stack = Uint32List(w * h);
  int total = 0;

  for (final CanvasIsland island in islands) {
    final int target = island.escapeCount;
    // Unknown count, or a count that collides with the non-escaping sentinel.
    if (target < 0 || target >= raster.maxIterations) {
      unfilled.add(island);
      continue;
    }
    final int filled = _fillOne(
      mask: mask,
      stack: stack,
      counts: raster.counts,
      widthPx: w,
      heightPx: h,
      escapeCount: target,
      pointsReIm: island.pointsReIm,
      math: math,
    );
    if (filled == 0) {
      unfilled.add(island);
    } else {
      total += filled;
    }
  }

  return IslandFillResult(
    mask: mask,
    widthPx: w,
    heightPx: h,
    filledPixels: total,
    unfilled: unfilled,
  );
}

/// Seed from every point of one island and flood its level set into [mask].
/// Returns the number of pixels this island contributed.
///
/// The fill is 4-connected and marks on push, so a pixel enters [stack] at most
/// once and the traversal is bounded by the raster. [mask] is shared across
/// islands in a pass, which also dedupes seeds for free — a repeated point, or
/// one already reached by the fill, costs a single array read.
int _fillOne({
  required Uint8List mask,
  required Uint32List stack,
  required Uint32List counts,
  required int widthPx,
  required int heightPx,
  required int escapeCount,
  required List<double> pointsReIm,
  required ViewportMath math,
}) {
  int top = 0;
  int filled = 0;

  for (int i = 0; i + 1 < pointsReIm.length; i += 2) {
    final int idx = rasterIndexOf(
      math: math,
      widthPx: widthPx,
      heightPx: heightPx,
      re: pointsReIm[i],
      im: pointsReIm[i + 1],
    );
    // Off-raster seeds are dropped: an island reaching into the view from
    // outside it is filled through whichever of its points are on screen.
    if (idx < 0) continue;
    if (mask[idx] != 0) continue;
    // The seed is an exact coordinate but the raster samples pixel centres, so
    // a seed can land in a pixel of a neighbouring level set. Requiring the
    // island's own count (rather than adopting whatever the seed pixel holds)
    // keeps the fill from locking onto the wrong band.
    if (counts[idx] != escapeCount) continue;
    mask[idx] = 255;
    stack[top++] = idx;
    filled++;
  }

  while (top > 0) {
    final int idx = stack[--top];
    final int x = idx % widthPx;
    final int y = idx ~/ widthPx;

    if (x > 0) {
      final int n = idx - 1;
      if (mask[n] == 0 && counts[n] == escapeCount) {
        mask[n] = 255;
        stack[top++] = n;
        filled++;
      }
    }
    if (x + 1 < widthPx) {
      final int n = idx + 1;
      if (mask[n] == 0 && counts[n] == escapeCount) {
        mask[n] = 255;
        stack[top++] = n;
        filled++;
      }
    }
    if (y > 0) {
      final int n = idx - widthPx;
      if (mask[n] == 0 && counts[n] == escapeCount) {
        mask[n] = 255;
        stack[top++] = n;
        filled++;
      }
    }
    if (y + 1 < heightPx) {
      final int n = idx + widthPx;
      if (mask[n] == 0 && counts[n] == escapeCount) {
        mask[n] = 255;
        stack[top++] = n;
        filled++;
      }
    }
  }

  return filled;
}

/// Row-major index of the raster pixel containing fractal coordinate
/// `(re, im)`, or `-1` if it falls outside the raster.
///
/// [ViewportMath.coordToPixel] returns the continuous pixel coordinate under the
/// "pixel `p` is sampled at its centre" convention, so the containing pixel is
/// the nearest integer.
int rasterIndexOf({
  required ViewportMath math,
  required int widthPx,
  required int heightPx,
  required double re,
  required double im,
}) {
  final (double px, double py) = math.coordToPixel(re, im);
  if (px.isNaN || py.isNaN) return -1;
  final int x = px.round();
  final int y = py.round();
  if (x < 0 || x >= widthPx || y < 0 || y >= heightPx) return -1;
  return y * widthPx + x;
}
