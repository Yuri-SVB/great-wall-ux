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

/// Holds the brightness-exponent offset (`beo`) for a session.
///
/// Invariants (TKBA, per `TECH_STACK.md`):
/// - Always reset to [kDefaultBrightnessOffset] at construction; the offset
///   is **never persisted** across sessions.
/// - The value is **never surfaced** — there is no getter that formats it
///   for display, no logging, no readout. The during-navigation adjustment
///   is tacit by design; exposing the number would make it verbalizable.
///
/// The brightness falloff itself is always on; there is no enable/disable
/// toggle (the prototype's `L` on/off toggle is dropped).
class BrightnessController extends ChangeNotifier {
  BrightnessController({
    this.defaultOffset = kDefaultBrightnessOffset,
    this.step = kBrightnessStep,
  }) : _offset = defaultOffset;

  final double defaultOffset;
  final double step;

  double _offset;

  /// Current offset. Consumed only by the shader uniform; intentionally not
  /// formatted for display anywhere.
  double get offset => _offset;

  /// Adjust by [steps] increments of [step] (positive brightens the lit
  /// band, negative darkens). `L` + scroll calls this with ±1.
  void adjustBySteps(double steps) => _set(_offset + steps * step);

  /// Reset to the session default. Called at the start of each session.
  void reset() => _set(defaultOffset);

  void _set(double value) {
    if (value == _offset) return;
    _offset = value;
    notifyListeners();
  }
}
