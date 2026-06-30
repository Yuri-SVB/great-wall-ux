import 'package:flutter/foundation.dart';

import '../stages/stage.dart';
import 'viewport.dart';

/// Default soft cap on the number of distinct leaf areas enumerated for a view.
///
/// Above this the view is considered too busy to highlight individually and the
/// UX should prompt the user to zoom in (see [LeafAreasResult.tooMany]).
const int kDefaultMaxLeafAreas = 20;

/// Default sampling stride, in pixels, for the leaf-area scan.
///
/// The enumeration samples the view on an `N × N` grid; coarser strides are
/// cheaper and still find every leaf area large enough to matter, because a
/// processed leaf (or contracted-away region) excludes the rest of itself from
/// the scan. `1` would sample every pixel.
const int kDefaultLeafAreaScanStep = 4;

/// A single canonical leaf area present in a view.
///
/// The rectangle is in fractal coordinates (the leaf's final, contracted
/// bisection rect). [path] is the bisection path string the core produced for
/// the leaf — its canonical identity, stable across frames and zoom levels, so
/// the UX can track "the same leaf" as the view moves.
@immutable
class LeafArea {
  const LeafArea({
    required this.reMin,
    required this.reMax,
    required this.imMin,
    required this.imMax,
    required this.path,
  });

  final double reMin;
  final double reMax;
  final double imMin;
  final double imMax;

  /// Bisection path — the leaf area's canonical identity.
  final String path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeafArea &&
          other.reMin == reMin &&
          other.reMax == reMax &&
          other.imMin == imMin &&
          other.imMax == imMax &&
          other.path == path;

  @override
  int get hashCode => Object.hash(reMin, reMax, imMin, imMax, path);
}

/// A request to enumerate the leaf areas present in a view.
///
/// Mirrors [EscapeCountRequest]: it carries the [viewport] that fixes the
/// pixel-to-coordinate mapping plus the fractal selection ([stage] /
/// [stageParameters]). The implementation decodes sampled points against the
/// protocol encode area; the bit depth and scan/cap knobs are passed through.
@immutable
class LeafAreasRequest {
  const LeafAreasRequest({
    required this.viewport,
    required this.stage,
    required this.stageParameters,
    required this.numBits,
    this.scanStep = kDefaultLeafAreaScanStep,
    this.maxLeaves = kDefaultMaxLeafAreas,
  });

  final FractalViewport viewport;
  final Stage stage;

  /// Stage-2 perturbation `(o, p, q)`. Required for [Stage.stage2], must be
  /// `null` for [Stage.stage1] (the canonical fractal has no parameters).
  final StageParameters? stageParameters;

  /// Number of bisection levels (bits) to decode — the encoding depth.
  final int numBits;

  /// Pixel stride for the scan grid (>= 1; clamped by the implementation).
  final int scanStep;

  /// Soft cap on distinct leaf areas before the result is [LeafAreasResult.tooMany].
  final int maxLeaves;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeafAreasRequest &&
          other.viewport == viewport &&
          other.stage == stage &&
          other.stageParameters == stageParameters &&
          other.numBits == numBits &&
          other.scanStep == scanStep &&
          other.maxLeaves == maxLeaves;

  @override
  int get hashCode =>
      Object.hash(viewport, stage, stageParameters, numBits, scanStep, maxLeaves);
}

/// The outcome of a [LeafAreasRequest].
///
/// Either the (capped) list of distinct leaf areas present in the view, or the
/// [tooMany] signal meaning more than [maxLeaves] are present and the user
/// should zoom in.
@immutable
class LeafAreasResult {
  /// A successful enumeration carrying the distinct [leaves] found.
  const LeafAreasResult.leaves(this.leaves)
      : tooMany = false,
        maxLeaves = 0;

  /// Too many leaf areas: more than [maxLeaves] distinct areas are present.
  const LeafAreasResult.tooMany(this.maxLeaves)
      : leaves = const <LeafArea>[],
        tooMany = true;

  /// The distinct leaf areas present (empty when [tooMany]).
  final List<LeafArea> leaves;

  /// Whether the request exceeded the cap; [leaves] is then empty.
  final bool tooMany;

  /// The cap that was exceeded (only meaningful when [tooMany]).
  final int maxLeaves;
}

/// Boundary between the UX layer and `great-wall-core` for leaf-area
/// enumeration.
///
/// Like [EscapeCountSource], implementations live outside this library —
/// typically a `dart:ffi` binding to the Rust engine's `bs_leaf_areas_*`
/// family. The library never enumerates leaf areas itself (it has no fractal
/// arithmetic); it only consumes the list a source returns.
///
/// Implementations MUST be deterministic for a given [LeafAreasRequest].
abstract interface class LeafAreaSource {
  /// Enumerate the leaf areas present in [request]'s view.
  Future<LeafAreasResult> leafAreas(LeafAreasRequest request);
}

/// Stub source used until the Rust binding is wired in (and in widget tests /
/// the example app). Always reports an empty leaf-area list.
class StubLeafAreaSource implements LeafAreaSource {
  const StubLeafAreaSource();

  @override
  Future<LeafAreasResult> leafAreas(LeafAreasRequest request) async =>
      const LeafAreasResult.leaves(<LeafArea>[]);
}
