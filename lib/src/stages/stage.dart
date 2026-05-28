import 'package:flutter/foundation.dart';

/// Which of the two pipeline stages a canvas is rendering.
///
/// See `great-wall-docs/great-wallet/ARCHITECTURE.md` §"Two-Stage Pipeline".
enum Stage {
  /// Canonical Burning Ship fractal. Parameters are fixed protocol constants
  /// (no `StageParameters` required).
  stage1,

  /// User-specific perturbation parameterised by `(o, p, q)`.
  stage2,
}

/// Stage-2 perturbation parameters.
///
/// `(o, p, q)` is the deterministic output of `Argon2(stage-1 bits)`. They
/// exist only as ephemeral state during a rendering session — the UX layer
/// never persists them, and never displays them to the user.
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
