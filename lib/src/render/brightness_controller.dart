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
/// for a session, and whether they follow the screen automatically. The
/// shader lights escape count `n` by `1 / (1 + 2^((n - h) / s))`, half
/// brightness at
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
/// **Auto exposure.** While [autoExposure] is on, the canvas sets offset and
/// slope itself from each frame's escape counts (`screen_exposure.dart`,
/// eased in over a fraction of a second) through [setExposure]. Any manual
/// adjustment — [adjustBySteps] or [adjustSlopeBySteps] — turns it off, and
/// adjustment continues from the values it had reached. Like the values, the
/// mode is never persisted.
///
/// The brightness falloff itself is always on; there is no enable/disable
/// toggle (the prototype's `L` on/off toggle is dropped).
class BrightnessController extends ChangeNotifier {
  BrightnessController({
    this.defaultOffset = kDefaultBrightnessOffset,
    this.step = kBrightnessStep,
    this.defaultSlope = kDefaultBrightnessSlope,
    this.slopeStepsPerDoubling = kBrightnessSlopeStepsPerDoubling,
    bool autoExposure = false,
  })  : _offset = defaultOffset,
        _slope = defaultSlope,
        _auto = autoExposure;

  final double defaultOffset;
  final double step;
  final double defaultSlope;
  final double slopeStepsPerDoubling;

  double _offset;
  double _slope;
  bool _auto;

  /// Current offset. Consumed only by the shader uniform; intentionally not
  /// formatted for display anywhere.
  double get offset => _offset;

  /// Current slope. Consumed only by the shader uniform; intentionally not
  /// formatted for display anywhere.
  double get slope => _slope;

  /// Whether offset and slope follow the screen (see the class comment).
  bool get autoExposure => _auto;

  set autoExposure(bool on) {
    if (on == _auto) return;
    _auto = on;
    notifyListeners();
  }

  /// Flip [autoExposure]. The host binds this to `A`.
  void toggleAutoExposure() => autoExposure = !_auto;

  /// Adjust by [steps] increments of [step] (positive brightens the lit
  /// band, negative darkens). `L` + scroll calls this with ±1. Turns
  /// [autoExposure] off.
  void adjustBySteps(double steps) =>
      _set(_offset + steps * step, _slope, auto: false);

  /// Adjust the slope by [steps]: [slopeStepsPerDoubling] steps double it
  /// (positive spreads the falloff over more counts, negative sharpens it).
  /// `G` + scroll calls this with ±1. Turns [autoExposure] off.
  void adjustSlopeBySteps(double steps) => _set(
        _offset,
        _slope * math.pow(2.0, steps / slopeStepsPerDoubling),
        auto: false,
      );

  /// Set offset and slope as auto exposure computed them, leaving
  /// [autoExposure] as it is. [slope] must be positive.
  void setExposure({required double offset, required double slope}) {
    assert(slope > 0, 'slope must be positive');
    _set(offset, slope, auto: _auto);
  }

  /// Reset offset and slope to the session defaults. Called at the start of
  /// each session (and by hosts on recentring). [autoExposure] is kept: if on,
  /// the next frame re-exposes from the defaults.
  void reset() => _set(defaultOffset, defaultSlope, auto: _auto);

  void _set(double offset, double slope, {required bool auto}) {
    if (offset == _offset && slope == _slope && auto == _auto) return;
    _offset = offset;
    _slope = slope;
    _auto = auto;
    notifyListeners();
  }
}
