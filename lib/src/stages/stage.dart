import 'package:flutter/foundation.dart';

/// Which kind of fractal a canvas is rendering: the pure canonical Burning Ship,
/// or an `(o, p, q)`-perturbed one.
///
/// Both render paths remain available to consumers of this library. Note that
/// the Great Wall *chained* protocol with a text Stage 0 no longer uses a shared
/// canonical fractal at all — every chain fractal is derived from the Stage-0
/// salt/pepper plus the preceding points, so it is rendered through the
/// perturbed path with its own reservoirs. The canonical path ([stage1]) is
/// kept for the standalone viewer / examples and any non-chained use.
enum Stage {
  /// Canonical Burning Ship fractal. Parameters are fixed protocol constants
  /// (no `StageParameters` required). Not used by the chained wallet flow.
  stage1,

  /// A chain-derived, user-specific perturbation parameterised by `(o, p, q)`.
  stage2,
}

/// A chained stage's perturbation parameters.
///
/// `(o, p, q)` is the deterministic output of the memory-hard chain over all
/// preceding points (`SHA-256(Argon2^N(points 0..k-1))`). They exist only as
/// ephemeral state during a rendering session — the UX layer never persists
/// them, and never displays them to the user.
@immutable
class StageParameters {
  const StageParameters({required this.o, required this.p, required this.q});

  final double o;
  final double p;
  final double q;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StageParameters && other.o == o && other.p == p && other.q == q;

  @override
  int get hashCode => Object.hash(o, p, q);

  /// `toString` is intentionally redacted. Logging `(o, p, q)` would leak
  /// material that is supposed to live only inside an active session — the
  /// "no logs of fractal coordinates" invariant in `TECH_STACK.md`.
  @override
  String toString() => 'StageParameters(<redacted>)';
}
