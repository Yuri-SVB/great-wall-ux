import 'package:flutter/foundation.dart';

/// Result of a select-mode click/tap on the fractal canvas.
@immutable
class FractalSelection {
  const FractalSelection({
    required this.re,
    required this.im,
    required this.pixelX,
    required this.pixelY,
  });

  final double re;
  final double im;

  /// Logical pixel coordinates at the moment of selection. Preserved so
  /// downstream consumers (training flow, point-by-point confirm) can
  /// reproduce the marker placement without re-running `coordToPixel`.
  final double pixelX;
  final double pixelY;

  /// `toString` is intentionally redacted. The selection coordinates ARE
  /// coercion-relevant material — see the "no logs of fractal coordinates"
  /// invariant in `great-wall-docs/great-wall-ux/TECH_STACK.md`.
  @override
  String toString() => 'FractalSelection(<redacted>)';
}
