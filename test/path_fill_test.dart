import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:great_wall_ux/great_wall_ux.dart';
import 'package:great_wall_ux/src/canvas/path_fill.dart';

/// A viewport whose raster is [w] x [h] pixels with 1 fractal unit per pixel,
/// pixel (x, y) at coordinate (x, y) (as in island_fill_test.dart).
FractalViewport _unitViewport(int w, int h) => FractalViewport(
      centreRe: w / 2.0 - 0.5,
      centreIm: h / 2.0 - 0.5,
      halfExtent: (w < h ? w : h) / 2.0,
      widthPx: w,
      heightPx: h,
      devicePixelRatio: 1.0,
    );

EscapeCountRaster _raster(List<List<int>> rows, {int maxIterations = 64}) {
  final int h = rows.length;
  final int w = rows.first.length;
  final Uint32List counts = Uint32List(w * h);
  for (int y = 0; y < h; y++) {
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

/// Cells of size [size] at grid positions [at], origin (0, 0).
CanvasCells _cells(
  List<(int, int)> at, {
  double size = 1.0,
  int w = 8,
  int h = 8,
}) {
  final Uint8List bytes = Uint8List(w * h);
  for (final (int x, int y) in at) {
    bytes[y * w + x] = 1;
  }
  return CanvasCells(
    originRe: 0,
    originIm: 0,
    cellSize: size,
    width: w,
    height: h,
    cells: bytes,
  );
}

List<int> _row(Uint8List mask, int w, int y) =>
    mask.sublist(y * w, (y + 1) * w).toList();

void main() {
  const int c = 255;

  test('a count range floods from the cells through the range only', () {
    final EscapeCountRaster r = _raster(<List<int>>[
      <int>[9, 9, 9, 9, 9],
      <int>[9, 5, 6, 7, 9],
      <int>[9, 9, 9, 8, 9],
    ]);
    final CanvasPath path = CanvasPath(
      stops: <CanvasPathStop>[
        CanvasPathStop(
          re: 1,
          im: 1,
          cells: _cells(<(int, int)>[(1, 1)]),
          countLow: 5,
          countHigh: 7,
        ),
      ],
    );
    final Uint8List mask =
        fillPath(raster: r, rasterViewport: _unitViewport(5, 3), path: path);
    expect(_row(mask, 5, 1), <int>[0, c, c, c, 0]);
    expect(
      _row(mask, 5, 2),
      <int>[0, 0, 0, 0, 0],
      reason: '8 is above the range',
    );
  });

  test('cells are drawn without a count range', () {
    final EscapeCountRaster r = _raster(<List<int>>[
      <int>[1, 1, 1, 1],
      <int>[1, 1, 1, 1],
    ]);
    final CanvasPath path = CanvasPath(
      stops: <CanvasPathStop>[
        CanvasPathStop(
          re: 0,
          im: 0,
          cells: _cells(<(int, int)>[(0, 0), (2, 1)]),
        ),
      ],
    );
    final Uint8List mask =
        fillPath(raster: r, rasterViewport: _unitViewport(4, 2), path: path);
    expect(_row(mask, 4, 0), <int>[c, 0, 0, 0]);
    expect(_row(mask, 4, 1), <int>[0, 0, c, 0]);
  });

  test('a range reaching the render cap falls back to the cells', () {
    final EscapeCountRaster r = _raster(
      <List<int>>[
        <int>[64, 64, 64],
      ],
      maxIterations: 64,
    );
    final CanvasPath path = CanvasPath(
      stops: <CanvasPathStop>[
        CanvasPathStop(
          re: 1,
          im: 0,
          cells: _cells(<(int, int)>[(1, 0)]),
          countLow: 60,
          countHigh: 65,
        ),
      ],
    );
    final Uint8List mask =
        fillPath(raster: r, rasterViewport: _unitViewport(3, 1), path: path);
    expect(mask.toList(), <int>[0, c, 0], reason: 'the cell, not the void');
  });

  test('touching features each fill whole', () {
    final EscapeCountRaster r = _raster(<List<int>>[
      <int>[3, 3, 4, 4],
    ]);
    final CanvasPath path = CanvasPath(
      stops: <CanvasPathStop>[
        CanvasPathStop(
          re: 0,
          im: 0,
          cells: _cells(<(int, int)>[(0, 0)]),
          countLow: 3,
          countHigh: 4,
        ),
        CanvasPathStop(
          re: 3,
          im: 0,
          cells: _cells(<(int, int)>[(3, 0)]),
          countLow: 4,
          countHigh: 4,
        ),
      ],
    );
    final Uint8List mask =
        fillPath(raster: r, rasterViewport: _unitViewport(4, 1), path: path);
    expect(mask.toList(), <int>[c, c, c, c]);
  });

  test('CanvasCells.contains maps a point to its cell', () {
    final CanvasCells cells = _cells(<(int, int)>[(2, 3)], size: 0.5);
    expect(cells.contains(1.0, 1.5), isTrue);
    expect(cells.contains(1.2, 1.6), isTrue);
    expect(cells.contains(1.3, 1.5), isFalse);
    expect(cells.contains(-1.0, 1.5), isFalse);
  });
}
