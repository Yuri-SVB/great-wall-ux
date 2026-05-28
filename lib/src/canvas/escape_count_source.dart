import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../stages/stage.dart';
import 'viewport.dart';
import 'viewport_math.dart';

/// A request for one full-viewport escape-count raster.
@immutable
class EscapeCountRequest {
  const EscapeCountRequest({
    required this.viewport,
    required this.stage,
    required this.stageParameters,
    required this.maxIterations,
  });

  final FractalViewport viewport;
  final Stage stage;

  /// Stage-2 perturbation `(o, p, q)`. Required for [Stage.stage2], must be
  /// `null` for [Stage.stage1] (the canonical fractal has no parameters).
  final StageParameters? stageParameters;

  /// Iteration cap. The core decides what to do beyond this; the UX layer
  /// only passes it through.
  final int maxIterations;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EscapeCountRequest &&
          other.viewport == viewport &&
          other.stage == stage &&
          other.stageParameters == stageParameters &&
          other.maxIterations == maxIterations;

  @override
  int get hashCode =>
      Object.hash(viewport, stage, stageParameters, maxIterations);
}

/// The escape-count raster returned by an [EscapeCountSource].
///
/// `counts` is a row-major `widthPx * heightPx` buffer. Each entry is the
/// escape iteration count for the corresponding pixel (or `maxIterations`
/// for points that did not escape).
@immutable
class EscapeCountRaster {
  const EscapeCountRaster({
    required this.widthPx,
    required this.heightPx,
    required this.maxIterations,
    required this.counts,
  });

  final int widthPx;
  final int heightPx;
  final int maxIterations;
  final Uint32List counts;
}

/// Boundary between the UX layer and `great-wall-core`.
///
/// Implementations live outside this library — typically a Dart `dart:ffi`
/// binding to the Rust engine. The library never computes escape counts
/// itself: the Burning Ship is computed by the Rust core (see
/// `great-wall-docs/great-wall-ux/SCOPE.md`).
///
/// All implementations MUST be deterministic for a given [EscapeCountRequest]:
/// same input bits → same output bits, on every platform.
abstract interface class EscapeCountSource {
  /// Compute the escape-count raster for [request].
  ///
  /// Implementations may run the work on a Rust-side thread pool and resolve
  /// the future when results are available. The UI layer drives
  /// back-pressure (low-res-then-refine) via the [FractalViewport] downsampling
  /// strategy in the canvas widget; this method does only what it is asked.
  Future<EscapeCountRaster> escapeCounts(EscapeCountRequest request);
}

/// Stub implementation used until the Rust binding is wired in.
///
/// Returns an all-zero raster. This exists solely so the rest of the UX
/// stack can be exercised in widget tests and the example app without
/// pulling in the Rust toolchain. It is NOT a fallback renderer — the
/// scope doc explicitly forbids a parallel Dart fractal implementation.
class StubEscapeCountSource implements EscapeCountSource {
  const StubEscapeCountSource();

  @override
  Future<EscapeCountRaster> escapeCounts(EscapeCountRequest request) async {
    final int n = request.viewport.widthPx * request.viewport.heightPx;
    return EscapeCountRaster(
      widthPx: request.viewport.widthPx,
      heightPx: request.viewport.heightPx,
      maxIterations: request.maxIterations,
      counts: Uint32List(n),
    );
  }
}

/// Development-only source that fills a **synthetic** escape-count field so
/// the colour pipeline (palette, hue rotation, brightness) is visible
/// without the Rust FFI binding.
///
/// This is NOT a fractal and must never be shipped: it is banded test data
/// in viewport coordinate space (a central "inside" disk plus sinusoidal
/// bands), used only to exercise the renderer in the example app and manual
/// testing. The real escape counts come from `great-wall-core`.
class DemoEscapeCountSource implements EscapeCountSource {
  const DemoEscapeCountSource();

  @override
  Future<EscapeCountRaster> escapeCounts(EscapeCountRequest request) async {
    final FractalViewport vp = request.viewport;
    final ViewportMath m = ViewportMath(vp);
    final int maxIter = request.maxIterations;
    final Uint32List counts = Uint32List(vp.widthPx * vp.heightPx);
    for (int y = 0; y < vp.heightPx; y++) {
      for (int x = 0; x < vp.widthPx; x++) {
        final (double re, double im) = m.pixelToCoord(x.toDouble(), y.toDouble());
        int n;
        if (re * re + im * im < 0.25) {
          n = maxIter; // central "inside the set" disk
        } else {
          final double v = 0.5 + 0.5 * math.sin(re * 6.0) * math.cos(im * 6.0);
          n = (v * (maxIter - 1)).round().clamp(0, maxIter - 1);
        }
        counts[y * vp.widthPx + x] = n;
      }
    }
    return EscapeCountRaster(
      widthPx: vp.widthPx,
      heightPx: vp.heightPx,
      maxIterations: maxIter,
      counts: counts,
    );
  }
}
