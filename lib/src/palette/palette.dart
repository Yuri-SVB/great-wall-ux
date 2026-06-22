import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// One of the six selectable hues for the fractal palette.
///
/// The set is fixed by `great-wall-docs/great-wall-ux/TECH_STACK.md`
/// §"Locked sub-decisions / Palette set": six hues evenly spaced around the
/// wheel (60° apart), named by hue. Within any one scheme the hue is
/// **constant** — only brightness varies — so the user reads detail by a
/// single perceptual dimension rather than by an arbitrary, distracting hue
/// ramp. The six-option set ossifies the palette surface: users switch by an
/// explicit, labelled wheel action, never by cycle-on-keypress, and the
/// variants are distinct enough that the user cannot drift between them by
/// accident.
enum HueOffset {
  red(0),
  yellow(60),
  green(120),
  cyan(180),
  blue(240),
  magenta(300);

  const HueOffset(this.degrees);

  /// HSV hue in degrees for this scheme.
  final int degrees;
}

/// The default hue: green — a green-on-black terminal allusion, and the
/// hue requested as the default in `great-wall-docs`.
const HueOffset kDefaultHue = HueOffset.green;

/// Brightness ramp shaping. A mild gamma lift keeps the low escape-count
/// bands (the bulk of the structure hugging the set) from crushing to black,
/// so brightness stays a legible signal across the whole range. The GPU
/// brightness-falloff modulation (TECH_STACK.md §"Brightness modulation")
/// then sculpts which band is most lit; the two compose.
const double _defaultGamma = 0.85;

/// Opaque black for the inside-the-set entry.
const int _inside = 0x000000FF;

/// Frozen escape-count → RGBA mapping for one hue.
///
/// The palette surface is a **single hue at full saturation** whose
/// **brightness ramps with the palette index** — i.e. with the (fixed-log)
/// transformed escape count fed in by the shader. There is no user-extensible
/// palette loader, no multi-hue base, and no toggle for the escape-count
/// transform (the transform is fixed log; see
/// `great-wall-docs/great-wall-ux/TECH_STACK.md`).
///
/// Once a tagged release ships, the escape-count → RGBA mapping of every
/// hue is frozen forever — the **palette stability** invariant.
@immutable
class Palette {
  /// The default scheme (green). Equivalent to `Palette.forHue(kDefaultHue)`.
  static final Palette green = Palette.forHue(kDefaultHue);

  Palette._({
    required this.id,
    required this.hueOffset,
    required Uint32List rgba,
  }) : _rgba = rgba;

  /// Build the palette for [hue]: a constant-hue, full-saturation ramp whose
  /// brightness runs from black (lowest escape count) to the full-bright hue
  /// (highest escaping count). The final entry — the inside-the-set colour —
  /// is opaque black and is never tinted.
  ///
  /// Caching policy: callers may keep the returned [Palette] around; the LUT
  /// is immutable and cheap to retain. The library does not maintain a
  /// singleton cache to avoid coupling lifetime to global state.
  factory Palette.forHue(
    HueOffset hue, {
    int tableSize = 256,
    double gamma = _defaultGamma,
  }) {
    final Uint32List table = Uint32List(tableSize);
    final int last = tableSize - 1; // index reserved for inside-the-set
    final double hueDeg = hue.degrees.toDouble();
    for (int i = 0; i < last; i++) {
      // t in [0, 1] across the escaping entries [0, last - 1].
      final double t = last > 1 ? i / (last - 1) : 0.0;
      final double value = math.pow(t, gamma).toDouble();
      table[i] = _hsvToRgba(hueDeg, 1.0, value);
    }
    table[last] = _inside;
    return Palette._(id: 'hue-${hue.name}', hueOffset: hue, rgba: table);
  }

  /// Stable identifier — `"hue-green"`, `"hue-blue"`, …
  final String id;

  /// Which of the six hues this palette is.
  final HueOffset hueOffset;

  final Uint32List _rgba;

  /// Number of distinct escape-count buckets in the lookup table.
  int get size => _rgba.length;

  /// 32-bit packed RGBA8888 colour for escape count [iteration]. Counts
  /// out of range are clamped to the nearest end.
  int rgbaForIteration(int iteration) {
    if (iteration < 0) return _rgba[0];
    if (iteration >= _rgba.length) return _rgba[_rgba.length - 1];
    return _rgba[iteration];
  }

  /// Direct view onto the lookup table. Callers MUST NOT mutate.
  Uint32List get rgbaTable => _rgba;
}

/// Convert HSV (hue in degrees, saturation and value in `[0, 1]`) to a packed
/// `0xRRGGBBAA` colour with opaque alpha. Kept self-contained so palette
/// generation has no dependency on Flutter painting types.
int _hsvToRgba(double hueDeg, double s, double v) {
  final double h = (hueDeg % 360.0) / 60.0;
  final int sector = h.floor();
  final double f = h - sector;
  final double p = v * (1.0 - s);
  final double q = v * (1.0 - s * f);
  final double t = v * (1.0 - s * (1.0 - f));
  double r;
  double g;
  double b;
  switch (sector % 6) {
    case 0:
      r = v;
      g = t;
      b = p;
      break;
    case 1:
      r = q;
      g = v;
      b = p;
      break;
    case 2:
      r = p;
      g = v;
      b = t;
      break;
    case 3:
      r = p;
      g = q;
      b = v;
      break;
    case 4:
      r = t;
      g = p;
      b = v;
      break;
    default:
      r = v;
      g = p;
      b = q;
      break;
  }
  final int ri = (r * 255.0).round().clamp(0, 255);
  final int gi = (g * 255.0).round().clamp(0, 255);
  final int bi = (b * 255.0).round().clamp(0, 255);
  return (ri << 24) | (gi << 16) | (bi << 8) | 0xFF;
}
