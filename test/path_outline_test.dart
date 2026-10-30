import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:great_wall_ux/src/canvas/overlay.dart';
import 'package:great_wall_ux/src/canvas/path_outline.dart';

/// A feature's outline is traced from its cells alone: exact loops (holes
/// included), rounded copies, traced once per cell set.
void main() {
  CanvasCells cells(List<String> rows) {
    // Rows listed top (highest y) first; '#' is a cell of the set.
    final int h = rows.length;
    final int w = rows.first.length;
    final Uint8List bytes = Uint8List(w * h);
    for (int r = 0; r < h; r++) {
      for (int x = 0; x < w; x++) {
        if (rows[r][x] == '#') bytes[(h - 1 - r) * w + x] = 1;
      }
    }
    return CanvasCells(
      originRe: 0,
      originIm: 0,
      cellSize: 1,
      width: w,
      height: h,
      cells: bytes,
    );
  }

  Set<(double, double)> corners(Float64List loop) => <(double, double)>{
        for (int k = 0; k < loop.length; k += 2) (loop[k], loop[k + 1]),
      };

  test('one cell is one square loop', () {
    final CellOutline o = CellOutline.trace(cells(<String>['#']));
    expect(o.loops, hasLength(1));
    expect(
      corners(o.loops.single),
      <(double, double)>{(0, 0), (1, 0), (1, 1), (0, 1)},
    );
  });

  test('a straight run keeps only its corners', () {
    final CellOutline o = CellOutline.trace(cells(<String>['####']));
    expect(
      corners(o.loops.single),
      <(double, double)>{(0, 0), (4, 0), (4, 1), (0, 1)},
    );
  });

  test('cells touching at a corner stay separate loops', () {
    final CellOutline o = CellOutline.trace(cells(<String>['.#', '#.']));
    expect(o.loops, hasLength(2));
    expect(o.loops.map((Float64List l) => l.length ~/ 2).toList(), <int>[4, 4]);
  });

  test('a ring is an outer loop and a hole', () {
    final CellOutline o = CellOutline.trace(
      cells(<String>['###', '#.#', '###']),
    );
    expect(o.loops, hasLength(2));
    final List<Set<(double, double)>> c =
        o.loops.map(corners).toList(growable: false);
    expect(
      c,
      contains(equals(<(double, double)>{(0, 0), (3, 0), (3, 3), (0, 3)})),
    );
    expect(
      c,
      contains(equals(<(double, double)>{(1, 1), (2, 1), (2, 2), (1, 2)})),
    );
  });

  test('smoothing cuts corners, within the cells\' box', () {
    final CellOutline o = CellOutline.trace(cells(<String>['##', '#.']));
    final Float64List raw = o.loops.single;
    final Float64List smooth = o.smooth.single;
    // Each pass doubles the vertices.
    expect(smooth.length, raw.length * (1 << kOutlineSmoothPasses));
    for (int k = 0; k < smooth.length; k++) {
      expect(smooth[k], inInclusiveRange(0.0, 2.0));
    }
    expect(
      corners(smooth).contains((0.0, 0.0)),
      isFalse,
      reason: 'the corner is cut',
    );
  });

  test('outlineOf traces a cell set once', () {
    final CanvasCells c = cells(<String>['#']);
    expect(identical(outlineOf(c), outlineOf(c)), isTrue);
  });
}
