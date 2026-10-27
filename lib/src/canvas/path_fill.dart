import 'dart:typed_data';

import 'escape_count_source.dart';
import 'island_fill.dart' show rasterIndexOf;
import 'overlay.dart';
import 'viewport.dart';
import 'viewport_math.dart';

/// Coverage value of a highlighted pixel in a path mask.
const int _kCovered = 255;

/// The pixels of a [CanvasPath]'s feature highlights over one raster: a
/// row-major `widthPx × heightPx` mask parallel to [raster], [_kCovered] where
/// some stop's feature covers the pixel and `0` elsewhere.
///
/// A stop with a count range is flood filled from its cells through the
/// pixels whose counts lie in the range (see [CanvasPathStop]); a stop without
/// one, or whose fill takes no pixel here, has its cells drawn instead.
/// [rasterViewport] is the viewport the raster was rendered for, as for
/// `fillIslands`.
Uint8List fillPath({
  required EscapeCountRaster raster,
  required FractalViewport rasterViewport,
  required CanvasPath path,
}) {
  final int w = raster.widthPx;
  final int h = raster.heightPx;
  final Uint8List mask = Uint8List(w * h);
  // Per pixel, the (1-based) stop whose fill last reached it: each stop fills
  // independently, so features that touch do not block each other.
  final Int32List seen = Int32List(w * h);
  final Uint32List stack = Uint32List(w * h);
  final ViewportMath math = ViewportMath(rasterViewport);
  for (int k = 0; k < path.stops.length; k++) {
    final CanvasPathStop stop = path.stops[k];
    final int? lo = stop.countLow;
    final int? hi = stop.countHigh;
    final bool flooded = lo != null &&
        hi != null &&
        hi < raster.maxIterations &&
        _flood(
              raster: raster,
              math: math,
              cells: stop.cells,
              low: lo,
              high: hi,
              mark: k + 1,
              seen: seen,
              stack: stack,
              mask: mask,
            ) >
            0;
    if (!flooded) {
      _drawCells(raster: raster, math: math, cells: stop.cells, mask: mask);
    }
  }
  return mask;
}

/// Flood the pixels with counts in `[low, high]` 4-connected to the centres
/// of [cells] into [mask]. Returns the number of pixels taken.
int _flood({
  required EscapeCountRaster raster,
  required ViewportMath math,
  required CanvasCells cells,
  required int low,
  required int high,
  required int mark,
  required Int32List seen,
  required Uint32List stack,
  required Uint8List mask,
}) {
  final int w = raster.widthPx;
  final int h = raster.heightPx;
  final Uint32List counts = raster.counts;
  bool inRange(int idx) => counts[idx] >= low && counts[idx] <= high;
  int top = 0;
  int filled = 0;
  for (int y = 0; y < cells.height; y++) {
    for (int x = 0; x < cells.width; x++) {
      if (cells.cells[y * cells.width + x] == 0) continue;
      final int idx = rasterIndexOf(
        math: math,
        widthPx: w,
        heightPx: h,
        re: cells.originRe + x * cells.cellSize,
        im: cells.originIm + y * cells.cellSize,
      );
      if (idx < 0 || seen[idx] == mark || !inRange(idx)) continue;
      seen[idx] = mark;
      stack[top++] = idx;
    }
  }
  while (top > 0) {
    final int idx = stack[--top];
    mask[idx] = _kCovered;
    filled++;
    final int x = idx % w;
    final int y = idx ~/ w;
    if (x > 0 && seen[idx - 1] != mark && inRange(idx - 1)) {
      seen[idx - 1] = mark;
      stack[top++] = idx - 1;
    }
    if (x + 1 < w && seen[idx + 1] != mark && inRange(idx + 1)) {
      seen[idx + 1] = mark;
      stack[top++] = idx + 1;
    }
    if (y > 0 && seen[idx - w] != mark && inRange(idx - w)) {
      seen[idx - w] = mark;
      stack[top++] = idx - w;
    }
    if (y + 1 < h && seen[idx + w] != mark && inRange(idx + w)) {
      seen[idx + w] = mark;
      stack[top++] = idx + w;
    }
  }
  return filled;
}

/// Mark in [mask] every pixel whose centre lies in one of [cells].
void _drawCells({
  required EscapeCountRaster raster,
  required ViewportMath math,
  required CanvasCells cells,
  required Uint8List mask,
}) {
  final int w = raster.widthPx;
  final int h = raster.heightPx;
  final double half = cells.cellSize / 2.0;
  final (double ax, double ay) =
      math.coordToPixel(cells.originRe - half, cells.originIm - half);
  final (double bx, double by) = math.coordToPixel(
    cells.originRe + (cells.width - 1) * cells.cellSize + half,
    cells.originIm + (cells.height - 1) * cells.cellSize + half,
  );
  final int x0 = (ax < bx ? ax : bx).floor().clamp(0, w - 1);
  final int x1 = (ax > bx ? ax : bx).ceil().clamp(0, w - 1);
  final int y0 = (ay < by ? ay : by).floor().clamp(0, h - 1);
  final int y1 = (ay > by ? ay : by).ceil().clamp(0, h - 1);
  for (int y = y0; y <= y1; y++) {
    for (int x = x0; x <= x1; x++) {
      final (double re, double im) =
          math.pixelToCoord(x.toDouble(), y.toDouble());
      if (cells.contains(re, im)) mask[y * w + x] = _kCovered;
    }
  }
}
