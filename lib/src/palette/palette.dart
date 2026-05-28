import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// One of the six hue rotations applied to the Classic base palette.
///
/// The set is fixed by `great-wall-docs/great-wall-ux/TECH_STACK.md`
/// §"Locked sub-decisions / Palette set". Six rotations at 60° spacing,
/// named by dominant hue. The set ossifies the palette surface: users
/// switch by an explicit, labelled action, never by cycle-on-keypress, and
/// the variants are visually distinct enough that the user cannot drift
/// between them by accident.
enum HueOffset {
  red(0),
  yellow(60),
  green(120),
  cyan(180),
  blue(240),
  magenta(300);

  const HueOffset(this.degrees);

  /// Hue rotation in degrees applied to the Classic base palette.
  final int degrees;
}

/// Frozen escape-count → RGBA mapping.
///
/// The palette surface is the Classic base inherited from `great-wall-core`,
/// available in the six rotations listed by [HueOffset]. There is no
/// user-extensible palette loader, no other base palette, and no toggle
/// for the escape-count transform (the transform is fixed log; see
/// `great-wall-docs/great-wall-ux/TECH_STACK.md`).
///
/// Once a tagged release ships, the escape-count → RGBA mapping of every
/// variant is frozen forever — the **palette stability** invariant.
@immutable
class Palette {
  /// The Classic palette with no hue rotation. Inherited from
  /// `great-wall-core`'s `palettes.py` `Classic` scheme.
  static final Palette classic = Palette._fromStops(
    id: 'classic',
    hueOffset: HueOffset.red,
    stops: const <_ClassicStop>[
      _ClassicStop(0.000, 0x000000FF),
      _ClassicStop(0.063, 0x1A237EFF),
      _ClassicStop(0.188, 0x3949ABFF),
      _ClassicStop(0.375, 0xF9A825FF),
      _ClassicStop(0.625, 0xFFD600FF),
      _ClassicStop(0.860, 0xFFFDE7FF),
    ],
    inside: 0x000000FF,
    tableSize: 256,
  );

  /// The Classic palette under [hue]. The variant is built deterministically
  /// from the same stops as [classic], with each stop's hue rotated by
  /// [HueOffset.degrees] in HSL space before being baked into the LUT.
  ///
  /// Caching policy: callers may keep the returned [Palette] around; the
  /// LUT is immutable and cheap to retain. The library does not maintain
  /// a singleton cache to avoid coupling lifetime to global state.
  factory Palette.classicWithHue(HueOffset hue) {
    if (hue == HueOffset.red) return classic;
    return Palette._fromStops(
      id: 'classic-${hue.name}',
      hueOffset: hue,
      stops: _classicStops,
      inside: 0x000000FF,
      tableSize: 256,
    );
  }

  Palette._({
    required this.id,
    required this.hueOffset,
    required Uint32List rgba,
  }) : _rgba = rgba;

  factory Palette._fromStops({
    required String id,
    required HueOffset hueOffset,
    required List<_ClassicStop> stops,
    required int inside,
    required int tableSize,
  }) {
    final Uint32List table = Uint32List(tableSize);
    for (int i = 0; i < tableSize - 1; i++) {
      final double t = i / (tableSize - 1);
      table[i] = _rotateHue(_sampleStops(stops, t), hueOffset.degrees);
    }
    table[tableSize - 1] = inside;
    return Palette._(id: id, hueOffset: hueOffset, rgba: table);
  }

  /// Stable identifier — `"classic"`, `"classic-blue"`, …
  final String id;

  /// Which of the six rotations this palette is.
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

@immutable
class _ClassicStop {
  const _ClassicStop(this.position, this.rgba);

  /// Position along the palette in `[0, 1]`. Position values are decoupled
  /// from any specific table size so the same stops generate identical
  /// shapes at any palette resolution.
  final double position;
  final int rgba;
}

const List<_ClassicStop> _classicStops = <_ClassicStop>[
  _ClassicStop(0.000, 0x000000FF),
  _ClassicStop(0.063, 0x1A237EFF),
  _ClassicStop(0.188, 0x3949ABFF),
  _ClassicStop(0.375, 0xF9A825FF),
  _ClassicStop(0.625, 0xFFD600FF),
  _ClassicStop(0.860, 0xFFFDE7FF),
];

int _sampleStops(List<_ClassicStop> stops, double t) {
  if (t <= stops.first.position) return stops.first.rgba;
  if (t >= stops.last.position) return stops.last.rgba;
  for (int i = 0; i + 1 < stops.length; i++) {
    final _ClassicStop a = stops[i];
    final _ClassicStop b = stops[i + 1];
    if (t >= a.position && t <= b.position) {
      final double u = (t - a.position) / (b.position - a.position);
      return _lerpRgba(a.rgba, b.rgba, u);
    }
  }
  return stops.last.rgba;
}

int _lerpRgba(int a, int b, double t) {
  final int ar = (a >> 24) & 0xFF;
  final int ag = (a >> 16) & 0xFF;
  final int ab = (a >> 8) & 0xFF;
  final int aa = a & 0xFF;
  final int br = (b >> 24) & 0xFF;
  final int bg = (b >> 16) & 0xFF;
  final int bb = (b >> 8) & 0xFF;
  final int ba = b & 0xFF;
  return ((ar + (br - ar) * t).round() << 24) |
      ((ag + (bg - ag) * t).round() << 16) |
      ((ab + (bb - ab) * t).round() << 8) |
      (aa + (ba - aa) * t).round();
}

/// Rotate an RGBA colour's hue by [degrees] in HSL space, preserving
/// saturation, lightness, and alpha. Used to produce the five non-Red
/// variants of the Classic palette from the same stops.
int _rotateHue(int rgba, int degrees) {
  if (degrees == 0) return rgba;
  final int r = (rgba >> 24) & 0xFF;
  final int g = (rgba >> 16) & 0xFF;
  final int b = (rgba >> 8) & 0xFF;
  final int a = rgba & 0xFF;

  final double rf = r / 255.0;
  final double gf = g / 255.0;
  final double bf = b / 255.0;

  final double maxC = math.max(rf, math.max(gf, bf));
  final double minC = math.min(rf, math.min(gf, bf));
  final double l = (maxC + minC) / 2.0;

  double h = 0.0;
  double s = 0.0;
  if (maxC != minC) {
    final double d = maxC - minC;
    s = l > 0.5 ? d / (2.0 - maxC - minC) : d / (maxC + minC);
    if (maxC == rf) {
      h = (gf - bf) / d + (gf < bf ? 6.0 : 0.0);
    } else if (maxC == gf) {
      h = (bf - rf) / d + 2.0;
    } else {
      h = (rf - gf) / d + 4.0;
    }
    h /= 6.0;
  }

  h = (h + degrees / 360.0) % 1.0;
  if (h < 0) h += 1.0;

  final double q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  final double p = 2 * l - q;
  final double r2 = _hueToChannel(p, q, h + 1 / 3);
  final double g2 = _hueToChannel(p, q, h);
  final double b2 = _hueToChannel(p, q, h - 1 / 3);

  return ((r2 * 255).round() << 24) |
      ((g2 * 255).round() << 16) |
      ((b2 * 255).round() << 8) |
      a;
}

double _hueToChannel(double p, double q, double t) {
  double tt = t;
  if (tt < 0) tt += 1;
  if (tt > 1) tt -= 1;
  if (tt < 1 / 6) return p + (q - p) * 6 * tt;
  if (tt < 1 / 2) return q;
  if (tt < 2 / 3) return p + (q - p) * (2 / 3 - tt) * 6;
  return p;
}
