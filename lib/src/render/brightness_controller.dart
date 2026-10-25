import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Brightness falloff base `B` from the inherited great-wall-core curve
/// (`constants.py: BRIGHTNESS_FALLOFF_BASE = 16`). Not user-adjustable.
const double kBrightnessFalloffBase = 16.0;

/// Session-default brightness-exponent offset
/// (`constants.py: BRIGHTNESS_EXPONENT_OFFSET = 4`).
const double kDefaultBrightnessOffset = 4.0;

/// Live-adjustment step for `L` + scroll. Deliberately fine (down from the
/// prototype's 1.5) so the during-navigation adjustment becomes a tacit
/// recognition skill rather than a few coarse presets. Expected to be tuned
/// empirically during dog-fooding. See
/// `great-wall-docs/great-wall-ux/TECH_STACK.md` §"Brightness modulation".
const double kBrightnessStep = 0.1;

/// Session-default brightness falloff slope `s`: 1 is the inherited
/// great-wall-core curve, `B / (B + 2^(n - beo) / z^2)`, unchanged.
const double kDefaultBrightnessSlope = 1.0;

/// Live-adjustment granularity for `G` + scroll: this many steps double (or
/// halve) the slope. Multiplicative, so the slope stays positive however far
/// it is adjusted; as fine as the offset's step, for the same tacit reason.
const double kBrightnessSlopeStepsPerDoubling = 10.0;

/// Holds the brightness-exponent offset (`beo`) and the falloff slope (`s`)
/// for a session. The shader lights escape count `n` by
/// `1 / (1 + 2^((n - h) / s))`, half brightness at
/// `h = beo + log2(B) + 2 log2(z)`: the offset moves the lit band, the slope
/// sets over how many counts it fades (more intermediate shades as it grows).
///
/// Invariants (TKBA, per `TECH_STACK.md`):
/// - Always reset to [kDefaultBrightnessOffset] and [kDefaultBrightnessSlope]
///   at construction; neither is **ever persisted** across sessions.
/// - The values are **never surfaced** — there is no getter that formats
///   them for display, no logging, no readout. The during-navigation
///   adjustment is tacit by design; exposing the numbers would make them
///   verbalizable.
///
/// The brightness falloff itself is always on; there is no enable/disable
/// toggle (the prototype's `L` on/off toggle is dropped).
class BrightnessController extends ChangeNotifier {
  BrightnessController({
    this.defaultOffset = kDefaultBrightnessOffset,
    this.step = kBrightnessStep,
    this.defaultSlope = kDefaultBrightnessSlope,
    this.slopeStepsPerDoubling = kBrightnessSlopeStepsPerDoubling,
  })  : _offset = defaultOffset,
        _slope = defaultSlope;

  final double defaultOffset;
  final double step;
  final double defaultSlope;
  final double slopeStepsPerDoubling;

  double _offset;
  double _slope;

  /// Current offset. Consumed only by the shader uniform; intentionally not
  /// formatted for display anywhere.
  double get offset => _offset;

  /// Current slope. Consumed only by the shader uniform; intentionally not
  /// formatted for display anywhere.
  double get slope => _slope;

  /// Adjust by [steps] increments of [step] (positive brightens the lit
  /// band, negative darkens). `L` + scroll calls this with ±1.
  void adjustBySteps(double steps) => _set(_offset + steps * step, _slope);

  /// Adjust the slope by [steps]: [slopeStepsPerDoubling] steps double it
  /// (positive spreads the falloff over more counts, negative sharpens it).
  /// `G` + scroll calls this with ±1.
  void adjustSlopeBySteps(double steps) => _set(
        _offset,
        _slope * math.pow(2.0, steps / slopeStepsPerDoubling),
      );

  /// Reset offset and slope to the session defaults. Called at the start of
  /// each session (and by hosts on recentring).
  void reset() => _set(defaultOffset, defaultSlope);

  void _set(double offset, double slope) {
    if (offset == _offset && slope == _slope) return;
    _offset = offset;
    _slope = slope;
    notifyListeners();
  }
}
