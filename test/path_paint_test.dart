import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:great_wall_ux/great_wall_ux.dart';
import 'package:great_wall_ux/src/canvas/canvas_painter.dart';

/// A landmark path's highlight is drawn from its cells' outline, where the
/// cells are: the same shape whatever the raster, at the right place and the
/// right way up.
void main() {
  // 4 fractal units across 100 px: 25 px per unit, the origin at (50, 50),
  // the imaginary axis growing downward (ViewportMath).
  const int sizePx = 100;
  const FractalViewport vp = FractalViewport(
    centreRe: 0.0,
    centreIm: 0.0,
    halfExtent: 2.0,
    widthPx: sizePx,
    heightPx: sizePx,
    devicePixelRatio: 1.0,
  );

  // One cell spanning re, im in [0, 1]; the stop's marker off screen.
  final CanvasPath path = CanvasPath(
    stops: <CanvasPathStop>[
      CanvasPathStop(
        re: 10,
        im: 10,
        cells: CanvasCells(
          originRe: 0.5,
          originIm: 0.5,
          cellSize: 1,
          width: 1,
          height: 1,
          cells: Uint8List.fromList(<int>[1]),
        ),
      ),
    ],
  );

  Future<ByteData> paint(WidgetTester tester) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    FractalCanvasPainter(
      viewport: vp,
      shader: null,
      overlays: CanvasOverlays(path: path),
      islandMask: null,
      islandCells: const <CanvasIsland>[],
      debugBisectionOverlay: false,
      repaintTick: 0,
    ).paint(Canvas(recorder), const Size(100, 100));
    final ByteData? bytes = await tester.runAsync<ByteData>(() async {
      final ui.Image image =
          await recorder.endRecording().toImage(sizePx, sizePx);
      final ByteData? data = await image.toByteData();
      image.dispose();
      return data!;
    });
    return bytes!;
  }

  int red(ByteData d, int x, int y) => d.getUint8((y * sizePx + x) * 4);

  testWidgets('the cell is highlighted where it is, the right way up',
      (WidgetTester tester) async {
    final ByteData d = await paint(tester);
    expect(red(d, 62, 62), greaterThan(0), reason: 're 0.5, im 0.5');
    expect(red(d, 62, 37), 0, reason: 'its mirror across the real axis');
    expect(red(d, 37, 62), 0, reason: 'its mirror across the imaginary axis');
    expect(red(d, 90, 90), 0);
  });

  testWidgets('large cells are drawn rounded', (WidgetTester tester) async {
    // 25 px a cell is past kOutlineSmoothFromPx: the corner is cut.
    final ByteData d = await paint(tester);
    expect(red(d, 50, 50), 0, reason: 'the cut corner');
    expect(red(d, 52, 62), greaterThan(0), reason: 'the edge between corners');
  });
}
