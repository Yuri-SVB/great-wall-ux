import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../palette/palette.dart';
import 'overlay.dart';
import 'viewport.dart';
import 'viewport_math.dart';

/// Reference half-extent used to derive the brightness `zoom` scalar.
///
/// Matches the default initial viewport half-extent, so `zoom == 1` at the
/// starting view and grows as the user zooms in (smaller half-extent). The
/// inherited brightness curve uses this to brighten on zoom.
const double kReferenceHalfExtent = 2.0;

/// Paints the fractal via a configured [ui.FragmentShader] and composites
/// overlays on top.
///
/// The shader is configured by the canvas widget before each paint (uniforms
/// + samplers); this painter only draws it. The fractal texture is the raw
/// escape-count buffer from `great-wall-core` — there is no fractal
/// arithmetic and no CPU colour loop here.
class FractalCanvasPainter extends CustomPainter {
  const FractalCanvasPainter({
    required this.viewport,
    required this.shader,
    required this.overlays,
    required this.debugBisectionOverlay,
    required this.repaintTick,
  });

  final FractalViewport viewport;

  /// Fully-configured fractal shader, or `null` while assets load (the
  /// painter draws a solid background in that case).
  final ui.FragmentShader? shader;

  final CanvasOverlays overlays;
  final bool debugBisectionOverlay;

  /// Monotonic counter bumped whenever uniforms change (viewport, brightness,
  /// palette). Lets [shouldRepaint] trigger on shader-uniform changes that
  /// are otherwise invisible to value equality.
  final int repaintTick;

  @override
  void paint(Canvas canvas, Size size) {
    final ui.FragmentShader? sh = shader;
    if (sh != null) {
      canvas.drawRect(Offset.zero & size, Paint()..shader = sh);
    } else {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF000000),
      );
    }

    final ViewportMath math = ViewportMath(viewport);

    // Canonical-island highlights: flat white cells, drawn under the markers.
    if (overlays.islands.isNotEmpty) {
      final double u = math.unitsPerPixel;
      // Disable anti-aliasing and overlap cells by a hairline so adjacent
      // cells fuse into a seamless solid shape rather than showing grid gaps.
      final Paint fill = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..isAntiAlias = false;
      for (final CanvasIsland island in overlays.islands) {
        final double sidePx = island.cellSize / u + 1.0;
        final List<double> pts = island.pointsReIm;
        for (int i = 0; i + 1 < pts.length; i += 2) {
          final (double cx, double cy) = math.coordToPixel(pts[i], pts[i + 1]);
          canvas.drawRect(
            Rect.fromCenter(center: Offset(cx, cy), width: sidePx, height: sidePx),
            fill,
          );
        }
      }
    }

    // Selection frames: white rectangles around chosen islands (over the cells).
    for (final SelectionFrame f in overlays.frames) {
      final (double x0, double y0) = math.coordToPixel(f.reMin, f.imMin);
      final (double x1, double y1) = math.coordToPixel(f.reMax, f.imMax);
      final double left = (x0 < x1 ? x0 : x1) - f.paddingPx;
      final double right = (x0 > x1 ? x0 : x1) + f.paddingPx;
      final double top = (y0 < y1 ? y0 : y1) - f.paddingPx;
      final double bottom = (y0 > y1 ? y0 : y1) + f.paddingPx;
      canvas.drawRect(
        Rect.fromLTRB(left, top, right, bottom),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = f.thicknessPx
          ..color = f.colour,
      );
    }

    if (debugBisectionOverlay) {
      final Paint stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0x80FF00FF);
      for (final BisectionRect r in overlays.bisectionRects) {
        final (double x0, double y0) = math.coordToPixel(r.reMin, r.imMax);
        final (double x1, double y1) = math.coordToPixel(r.reMax, r.imMin);
        canvas.drawRect(Rect.fromLTRB(x0, y0, x1, y1), stroke);
      }
    }

    if (overlays.crosshairs) {
      final Paint stroke = Paint()
        ..color = const Color(0xA0FFFFFF)
        ..strokeWidth = 1.0;
      final double cx = size.width / 2.0;
      final double cy = size.height / 2.0;
      canvas.drawLine(Offset(cx - 8, cy), Offset(cx + 8, cy), stroke);
      canvas.drawLine(Offset(cx, cy - 8), Offset(cx, cy + 8), stroke);
    }

    for (final PointMarker m in overlays.points) {
      final (double px, double py) = math.coordToPixel(m.re, m.im);
      canvas.drawCircle(Offset(px, py), m.radiusPx, Paint()..color = m.colour);
    }
  }

  @override
  bool shouldRepaint(covariant FractalCanvasPainter old) {
    return old.repaintTick != repaintTick ||
        old.viewport != viewport ||
        !identical(old.shader, shader) ||
        !identical(old.overlays, overlays) ||
        old.debugBisectionOverlay != debugBisectionOverlay;
  }
}

/// Pack a raw escape-count raster into an [ui.Image] for the shader to
/// sample. The count is stored normalised (`n / maxIterations`) in the red
/// channel; the shader reconstructs `n = r * maxIter`. Stored at the
/// raster's own resolution so a full-res frame maps 1:1 to fragments.
Future<ui.Image> packEscapeCounts({
  required int widthPx,
  required int heightPx,
  required Uint32List counts,
  required int maxIterations,
}) {
  final Uint8List rgba = Uint8List(widthPx * heightPx * 4);
  final double scale = maxIterations > 0 ? 255.0 / maxIterations : 0.0;
  for (int i = 0; i < counts.length; i++) {
    int v = (counts[i] * scale).round();
    if (v > 255) v = 255;
    final int o = i * 4;
    rgba[o] = v;
    rgba[o + 3] = 255;
  }
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    widthPx,
    heightPx,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

/// Build the palette lookup table as a `size × 1` [ui.Image] sampled by the
/// shader. Rebuilt only when the palette (hue rotation) changes — never on
/// the escape-count path.
Future<ui.Image> buildPaletteImage(Palette palette) {
  final Uint32List table = palette.rgbaTable;
  final Uint8List rgba = Uint8List(table.length * 4);
  for (int i = 0; i < table.length; i++) {
    final int c = table[i];
    final int o = i * 4;
    rgba[o] = (c >> 24) & 0xFF;
    rgba[o + 1] = (c >> 16) & 0xFF;
    rgba[o + 2] = (c >> 8) & 0xFF;
    rgba[o + 3] = c & 0xFF;
  }
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    table.length,
    1,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
