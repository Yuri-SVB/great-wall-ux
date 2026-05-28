import 'package:flutter/foundation.dart';

/// Immutable description of a fractal viewport.
///
/// The viewport is the single source of truth for the pixel-to-coordinate
/// mapping. It carries every input that affects that mapping: the centre of
/// the view in fractal coordinates, the half-extent in fractal units on the
/// shorter axis, the pixel size of the surface, and the device pixel ratio.
///
/// Two `FractalViewport` values that compare equal MUST produce a bit-identical
/// pixel-to-coordinate mapping on every supported platform. This is part of
/// the library's pixel-to-coordinate determinism invariant.
@immutable
class FractalViewport {
  const FractalViewport({
    required this.centreRe,
    required this.centreIm,
    required this.halfExtent,
    required this.widthPx,
    required this.heightPx,
    required this.devicePixelRatio,
  })  : assert(halfExtent > 0, 'halfExtent must be positive'),
        assert(widthPx > 0, 'widthPx must be positive'),
        assert(heightPx > 0, 'heightPx must be positive'),
        assert(devicePixelRatio > 0, 'devicePixelRatio must be positive');

  /// Real component of the viewport centre, in fractal coordinates.
  final double centreRe;

  /// Imaginary component of the viewport centre, in fractal coordinates.
  final double centreIm;

  /// Half-extent of the viewport on its shorter axis, in fractal units.
  ///
  /// The longer axis stretches proportionally; this preserves a square
  /// aspect ratio for the fractal coordinate grid regardless of the
  /// viewport's pixel aspect ratio.
  final double halfExtent;

  /// Width of the rendering surface in logical pixels.
  final int widthPx;

  /// Height of the rendering surface in logical pixels.
  final int heightPx;

  /// Device pixel ratio (logical → physical pixels). Part of the
  /// determinism contract: the same viewport on the same DPR renders
  /// identically across devices.
  final double devicePixelRatio;

  FractalViewport copyWith({
    double? centreRe,
    double? centreIm,
    double? halfExtent,
    int? widthPx,
    int? heightPx,
    double? devicePixelRatio,
  }) {
    return FractalViewport(
      centreRe: centreRe ?? this.centreRe,
      centreIm: centreIm ?? this.centreIm,
      halfExtent: halfExtent ?? this.halfExtent,
      widthPx: widthPx ?? this.widthPx,
      heightPx: heightPx ?? this.heightPx,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FractalViewport &&
        other.centreRe == centreRe &&
        other.centreIm == centreIm &&
        other.halfExtent == halfExtent &&
        other.widthPx == widthPx &&
        other.heightPx == heightPx &&
        other.devicePixelRatio == devicePixelRatio;
  }

  @override
  int get hashCode => Object.hash(
        centreRe,
        centreIm,
        halfExtent,
        widthPx,
        heightPx,
        devicePixelRatio,
      );
}
