import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:great_wall_ux/great_wall_ux.dart';
import 'package:great_wall_ux/src/canvas/island_fill.dart';

/// A viewport whose raster is [w] x [h] pixels with 1 fractal unit per pixel,
/// centred so pixel (0, 0) sits at coordinate (0, 0). That makes a pixel's
/// index and its coordinate the same number, so the tests read as pictures.
FractalViewport _unitViewport(int w, int h) => FractalViewport(
      centreRe: w / 2.0 - 0.5,
      centreIm: h / 2.0 - 0.5,
      halfExtent: (w < h ? w : h) / 2.0,
      widthPx: w,
      heightPx: h,
      devicePixelRatio: 1.0,
    );

/// Build a raster from rows of ints, one int per pixel.
EscapeCountRaster _raster(List<List<int>> rows, {int maxIterations = 64}) {
  final int h = rows.length;
  final int w = rows.first.length;
  final Uint32List counts = Uint32List(w * h);
  for (int y = 0; y < h; y++) {
    expect(rows[y].length, w, reason: 'ragged test raster');
    for (int x = 0; x < w; x++) {
      counts[y * w + x] = rows[y][x];
    }
  }
  return EscapeCountRaster(
    widthPx: w,
    heightPx: h,
    maxIterations: maxIterations,
    counts: counts,
  );
}

/// Island seeded at the given pixel centres (see [_unitViewport]).
CanvasIsland _islandAt(
  List<(int, int)> seeds, {
  required int escapeCount,
  double cellSize = 1.0,
}) {
  final List<double> pts = <double>[];
  for (final (int x, int y) in seeds) {
    pts..add(x.toDouble())..add(y.toDouble());
  }
  return CanvasIsland(
    cellSize: cellSize,
    pointsReIm: pts,
    escapeCount: escapeCount,
  );
}

List<int> _maskRow(IslandFillResult r, int y) =>
    r.mask.sublist(y * r.widthPx, (y + 1) * r.widthPx).toList();

void main() {
  group('rasterIndexOf', () {
    test('maps a coordinate to the pixel containing it', () {
      final ViewportMath m = ViewportMath(_unitViewport(4, 3));
      for (int y = 0; y < 3; y++) {
        for (int x = 0; x < 4; x++) {
          expect(
            rasterIndexOf(
              math: m,
              widthPx: 4,
              heightPx: 3,
              re: x.toDouble(),
              im: y.toDouble(),
            ),
            y * 4 + x,
            reason: 'pixel centre ($x,$y)',
          );
        }
      }
      // Off-centre within a pixel still resolves to that pixel.
      expect(
        rasterIndexOf(math: m, widthPx: 4, heightPx: 3, re: 2.4, im: 0.6),
        1 * 4 + 2,
      );
    });

    test('rejects coordinates outside the raster', () {
      final ViewportMath m = ViewportMath(_unitViewport(4, 3));
      expect(rasterIndexOf(math: m, widthPx: 4, heightPx: 3, re: -1.0, im: 0.0), -1);
      expect(rasterIndexOf(math: m, widthPx: 4, heightPx: 3, re: 4.0, im: 0.0), -1);
      expect(rasterIndexOf(math: m, widthPx: 4, heightPx: 3, re: 0.0, im: 3.0), -1);
      expect(rasterIndexOf(math: m, widthPx: 4, heightPx: 3, re: double.nan, im: 0.0), -1);
    });
  });

  group('fillIslands', () {
    test('one seed recovers the whole connected level set', () {
      // A plus-shaped region of count 7 in a field of 3. A single seed at its
      // centre must recover all five pixels — this is the whole point: the
      // island's extent comes from the raster, not from how many points the
      // core happened to sample.
      final EscapeCountRaster r = _raster(<List<int>>[
        <int>[3, 3, 3, 3, 3],
        <int>[3, 3, 7, 3, 3],
        <int>[3, 7, 7, 7, 3],
        <int>[3, 3, 7, 3, 3],
        <int>[3, 3, 3, 3, 3],
      ]);
      final IslandFillResult out = fillIslands(
        raster: r,
        rasterViewport: _unitViewport(5, 5),
        islands: <CanvasIsland>[
          _islandAt(<(int, int)>[(2, 2)], escapeCount: 7),
        ],
      );

      expect(out.filledPixels, 5);
      expect(out.unfilled, isEmpty);
      expect(_maskRow(out, 0), <int>[0, 0, 0, 0, 0]);
      expect(_maskRow(out, 1), <int>[0, 0, 255, 0, 0]);
      expect(_maskRow(out, 2), <int>[0, 255, 255, 255, 0]);
      expect(_maskRow(out, 3), <int>[0, 0, 255, 0, 0]);
      expect(_maskRow(out, 4), <int>[0, 0, 0, 0, 0]);
    });

    test('is the union of the fills, not one of them', () {
      // Two blobs of the same count, disconnected. A seed in each — the coarse
      // discovery lattice can bridge a neck that is not there at this
      // resolution, so both components must survive.
      final EscapeCountRaster r = _raster(<List<int>>[
        <int>[7, 7, 3, 7, 7],
        <int>[7, 7, 3, 7, 7],
      ]);
      final IslandFillResult out = fillIslands(
        raster: r,
        rasterViewport: _unitViewport(5, 2),
        islands: <CanvasIsland>[
          _islandAt(<(int, int)>[(0, 0), (4, 1)], escapeCount: 7),
        ],
      );

      expect(out.filledPixels, 8);
      expect(_maskRow(out, 0), <int>[255, 255, 0, 255, 255]);
      expect(_maskRow(out, 1), <int>[255, 255, 0, 255, 255]);
    });

    test('a seed in only one component leaves the other alone', () {
      final EscapeCountRaster r = _raster(<List<int>>[
        <int>[7, 7, 3, 7, 7],
        <int>[7, 7, 3, 7, 7],
      ]);
      final IslandFillResult out = fillIslands(
        raster: r,
        rasterViewport: _unitViewport(5, 2),
        islands: <CanvasIsland>[
          _islandAt(<(int, int)>[(0, 0)], escapeCount: 7),
        ],
      );

      expect(out.filledPixels, 4);
      expect(_maskRow(out, 0), <int>[255, 255, 0, 0, 0]);
    });

    test('fills 4-connected, not diagonally', () {
      // Two cells of count 7 touching only at a corner.
      final EscapeCountRaster r = _raster(<List<int>>[
        <int>[7, 3],
        <int>[3, 7],
      ]);
      final IslandFillResult out = fillIslands(
        raster: r,
        rasterViewport: _unitViewport(2, 2),
        islands: <CanvasIsland>[
          _islandAt(<(int, int)>[(0, 0)], escapeCount: 7),
        ],
      );

      expect(out.filledPixels, 1);
      expect(_maskRow(out, 0), <int>[255, 0]);
      expect(_maskRow(out, 1), <int>[0, 0]);
    });

    test('a resolution-floor island grows into its true shape', () {
      // The discovery lattice sampled a single cell of a region that is
      // genuinely nine pixels wide at this resolution. Before this change the
      // island rendered as that one cell (scaled into a block on zoom); now the
      // one point is a seed and the shape comes from the raster.
      final EscapeCountRaster r = _raster(<List<int>>[
        <int>[3, 3, 3, 3, 3],
        <int>[3, 7, 7, 7, 3],
        <int>[3, 7, 7, 7, 3],
        <int>[3, 7, 7, 7, 3],
        <int>[3, 3, 3, 3, 3],
      ]);
      final IslandFillResult out = fillIslands(
        raster: r,
        rasterViewport: _unitViewport(5, 5),
        islands: <CanvasIsland>[
          _islandAt(<(int, int)>[(2, 2)], escapeCount: 7),
        ],
      );
      expect(out.filledPixels, 9);
    });

    test('an island reaching in from off-screen fills through on-screen seeds', () {
      final EscapeCountRaster r = _raster(<List<int>>[
        <int>[7, 7, 3],
      ]);
      final IslandFillResult out = fillIslands(
        raster: r,
        rasterViewport: _unitViewport(3, 1),
        islands: <CanvasIsland>[
          // First seed is off-raster; the second is inside.
          _islandAt(<(int, int)>[(-40, 0), (1, 0)], escapeCount: 7),
        ],
      );
      expect(out.filledPixels, 2);
      expect(_maskRow(out, 0), <int>[255, 255, 0]);
    });

    test('reports an island whose count is absent from the raster as unfilled', () {
      // Every seed lands on a pixel of a different level set: the region is
      // real but thinner than this sample grid. It must be reported so the
      // caller can fall back to cells, not silently dropped.
      final EscapeCountRaster r = _raster(<List<int>>[
        <int>[3, 3],
        <int>[3, 3],
      ]);
      final CanvasIsland island =
          _islandAt(<(int, int)>[(0, 0), (1, 1)], escapeCount: 7);
      final IslandFillResult out = fillIslands(
        raster: r,
        rasterViewport: _unitViewport(2, 2),
        islands: <CanvasIsland>[island],
      );

      expect(out.isEmpty, isTrue);
      expect(out.unfilled, <CanvasIsland>[island]);
    });

    test('never floods the interior when the count collides with the sentinel', () {
      // A raster rendered under a cap of 8: non-escaping pixels are stored as
      // 8. An island discovered at the encoder's far larger cap can carry
      // escapeCount == 8, and matching it would paint the whole void white.
      final EscapeCountRaster r = _raster(
        <List<int>>[
          <int>[8, 8, 8],
          <int>[8, 8, 8],
        ],
        maxIterations: 8,
      );
      final CanvasIsland island =
          _islandAt(<(int, int)>[(1, 1)], escapeCount: 8);
      final IslandFillResult out = fillIslands(
        raster: r,
        rasterViewport: _unitViewport(3, 2),
        islands: <CanvasIsland>[island],
      );

      expect(out.filledPixels, 0, reason: 'must not flood the interior');
      expect(out.unfilled, <CanvasIsland>[island]);
    });

    test('an island with no escape count is left to the cell fallback', () {
      final EscapeCountRaster r = _raster(<List<int>>[
        <int>[7, 7],
      ]);
      const CanvasIsland island =
          CanvasIsland(cellSize: 1.0, pointsReIm: <double>[0.0, 0.0]);
      expect(island.escapeCount, CanvasIsland.unknownEscapeCount);

      final IslandFillResult out = fillIslands(
        raster: r,
        rasterViewport: _unitViewport(2, 1),
        islands: <CanvasIsland>[island],
      );
      expect(out.filledPixels, 0);
      expect(out.unfilled, <CanvasIsland>[island]);
    });

    test('several islands share one mask and each is reported', () {
      final EscapeCountRaster r = _raster(<List<int>>[
        <int>[7, 7, 0, 9, 9],
      ]);
      final CanvasIsland missing =
          _islandAt(<(int, int)>[(2, 0)], escapeCount: 5);
      final IslandFillResult out = fillIslands(
        raster: r,
        rasterViewport: _unitViewport(5, 1),
        islands: <CanvasIsland>[
          _islandAt(<(int, int)>[(0, 0)], escapeCount: 7),
          missing,
          _islandAt(<(int, int)>[(4, 0)], escapeCount: 9),
        ],
      );

      expect(out.filledPixels, 4);
      expect(out.unfilled, <CanvasIsland>[missing]);
      expect(_maskRow(out, 0), <int>[255, 255, 0, 255, 255]);
    });

    test('a raster that is entirely one island is filled, not refused', () {
      // Zooming into an island until it covers the view is the correct outcome,
      // not a runaway fill to guard against.
      final EscapeCountRaster r = _raster(<List<int>>[
        <int>[7, 7, 7],
        <int>[7, 7, 7],
        <int>[7, 7, 7],
      ]);
      final IslandFillResult out = fillIslands(
        raster: r,
        rasterViewport: _unitViewport(3, 3),
        islands: <CanvasIsland>[
          _islandAt(<(int, int)>[(1, 1)], escapeCount: 7),
        ],
      );
      expect(out.filledPixels, 9);
    });

    test('no islands yields an empty result of raster size', () {
      final EscapeCountRaster r = _raster(<List<int>>[
        <int>[7, 7],
        <int>[7, 7],
      ]);
      final IslandFillResult out = fillIslands(
        raster: r,
        rasterViewport: _unitViewport(2, 2),
        islands: const <CanvasIsland>[],
      );
      expect(out.isEmpty, isTrue);
      expect(out.mask.length, 4);
      expect(out.unfilled, isEmpty);
    });

    test('repeated and already-covered seeds are idempotent', () {
      final EscapeCountRaster r = _raster(<List<int>>[
        <int>[7, 7, 7],
      ]);
      final IslandFillResult out = fillIslands(
        raster: r,
        rasterViewport: _unitViewport(3, 1),
        islands: <CanvasIsland>[
          _islandAt(
            <(int, int)>[(0, 0), (0, 0), (1, 0), (2, 0), (1, 0)],
            escapeCount: 7,
          ),
        ],
      );
      expect(out.filledPixels, 3, reason: 'each pixel counted once');
    });
  });
}
