import 'package:flutter/foundation.dart';

import 'overlay.dart';

/// Chaikin passes that round a feature's outline; each pass doubles its
/// vertices.
const int kOutlineSmoothPasses = 2;

/// A highlight is drawn from the rounded outline once a cell spans this many
/// screen pixels (its steps would show); below, from the corner loops.
const double kOutlineSmoothFromPx = 4.0;

/// Chaikin's cut: each edge keeps its middle, from this fraction to its
/// complement.
const double _chaikinCut = 0.25;

/// A feature's outline, from its cells: the boundary of the cells as closed
/// loops, and the same loops rounded. Coordinates are in cell units from the
/// lower-left corner of cell `(0, 0)` — a cell `(x, y)` spans `[x, x+1] ×
/// [y, y+1]` — so they stay exact whatever the zoom. Filled with the
/// even-odd rule, the loops give the cells, holes included.
///
/// Fixed by the cells alone: no raster, no viewport. A highlight drawn from it
/// is the same at every pan and zoom.
@immutable
class CellOutline {
  const CellOutline({required this.loops, required this.smooth});

  /// Each loop's corners as `x0, y0, x1, y1, …`, closed implicitly.
  final List<Float64List> loops;

  /// [loops] after [kOutlineSmoothPasses] Chaikin passes.
  final List<Float64List> smooth;

  /// Trace the boundary of [cells].
  factory CellOutline.trace(CanvasCells cells) {
    final List<Float64List> loops = _traceLoops(cells);
    return CellOutline(
      loops: loops,
      smooth: <Float64List>[for (final Float64List l in loops) _chaikin(l)],
    );
  }
}

final Expando<CellOutline> _outlines = Expando<CellOutline>();

/// [cells]' outline, traced once per cell set and kept with it.
CellOutline outlineOf(CanvasCells cells) =>
    _outlines[cells] ??= CellOutline.trace(cells);

/// The boundary edges of the filled cells, each with the cells on its left,
/// chained into loops. Where two cells touch only at a corner, the walk turns
/// left, so each stays its own loop.
List<Float64List> _traceLoops(CanvasCells cells) {
  final int w = cells.width;
  final int h = cells.height;
  bool filled(int x, int y) =>
      x >= 0 && y >= 0 && x < w && y < h && cells.cells[y * w + x] != 0;
  final int stride = w + 1;
  int vertex(int x, int y) => y * stride + x;

  // Edges by start vertex; a vertex starts at most two (at a corner touch).
  final Map<int, List<int>> outgoing = <int, List<int>>{};
  final List<int> from = <int>[];
  final List<int> to = <int>[];
  void edge(int ax, int ay, int bx, int by) {
    outgoing.putIfAbsent(vertex(ax, ay), () => <int>[]).add(from.length);
    from.add(vertex(ax, ay));
    to.add(vertex(bx, by));
  }

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (!filled(x, y)) continue;
      if (!filled(x, y - 1)) edge(x, y, x + 1, y);
      if (!filled(x + 1, y)) edge(x + 1, y, x + 1, y + 1);
      if (!filled(x, y + 1)) edge(x + 1, y + 1, x, y + 1);
      if (!filled(x - 1, y)) edge(x, y + 1, x, y);
    }
  }

  final List<bool> used = List<bool>.filled(from.length, false);
  final List<Float64List> loops = <Float64List>[];
  for (int start = 0; start < from.length; start++) {
    if (used[start]) continue;
    final List<int> corners = <int>[];
    int e = start;
    while (!used[e]) {
      used[e] = true;
      corners.add(from[e]);
      final List<int> next = outgoing[to[e]]!;
      e = next.length == 1 ? next.first : _leftmost(next, e, from, to, stride);
    }
    loops.add(_dropStraight(corners, stride));
  }
  return loops;
}

/// Of the edges leaving a corner touch, the one turning left from edge [e].
int _leftmost(List<int> next, int e, List<int> from, List<int> to, int stride) {
  (int, int) dir(int k) => (
        to[k] % stride - from[k] % stride,
        to[k] ~/ stride - from[k] ~/ stride,
      );
  final (int dx, int dy) = dir(e);
  for (final int k in next) {
    final (int nx, int ny) = dir(k);
    if (nx == -dy && ny == dx) return k;
  }
  return next.first;
}

/// The loop's corners as coordinates, without the vertices where it runs
/// straight on.
Float64List _dropStraight(List<int> corners, int stride) {
  final int n = corners.length;
  final List<double> out = <double>[];
  for (int k = 0; k < n; k++) {
    final int a = corners[(k + n - 1) % n];
    final int b = corners[k];
    final int c = corners[(k + 1) % n];
    final int dx1 = b % stride - a % stride, dy1 = b ~/ stride - a ~/ stride;
    final int dx2 = c % stride - b % stride, dy2 = c ~/ stride - b ~/ stride;
    if (dx1 == dx2 && dy1 == dy2) continue;
    out
      ..add((b % stride).toDouble())
      ..add((b ~/ stride).toDouble());
  }
  return Float64List.fromList(out);
}

/// Chaikin's corner cutting, [kOutlineSmoothPasses] times, on a closed loop:
/// each edge `P→Q` becomes the points ¾P+¼Q and ¼P+¾Q ([_chaikinCut]).
Float64List _chaikin(Float64List loop) {
  Float64List p = loop;
  for (int pass = 0; pass < kOutlineSmoothPasses; pass++) {
    final int n = p.length ~/ 2;
    final Float64List q = Float64List(4 * n);
    for (int k = 0; k < n; k++) {
      final int j = (k + 1) % n;
      final double ax = p[2 * k], ay = p[2 * k + 1];
      final double bx = p[2 * j], by = p[2 * j + 1];
      const double keep = 1.0 - _chaikinCut;
      q[4 * k] = keep * ax + _chaikinCut * bx;
      q[4 * k + 1] = keep * ay + _chaikinCut * by;
      q[4 * k + 2] = _chaikinCut * ax + keep * bx;
      q[4 * k + 3] = _chaikinCut * ay + keep * by;
    }
    p = q;
  }
  return p;
}
