import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Screen exposure — the automatic brightness of the demo film
/// (great-wall-render `uxengine.exposure`): every frame fits the falloff
/// `1 / (1 + 2^((n − h) / s))` to its own escape counts, offset `h` and slope
/// `s` alike, so large features show their shells as distinct shades, the
/// filigree falls darker, and a higher count is never brighter.
///
/// The fit spans the smooth pixels' counts from this quantile to its
/// complement...
const double kExposureQuantile = 0.05;

/// ...lit from this brightness down to `1 −` it.
const double kExposureBand = 0.8;

/// Counts per halving of the falloff's tail, at least: the fit is never
/// steeper than this.
const double kExposureMinSlope = 2.0;

/// A pixel is smooth if its four neighbours are within this many counts of its
/// own: the interiors of shells and large features, not the filigree.
const int kExposureSmooth = 1;

/// The falloff's half-brightness count [h] and slope [s] fitted to one frame.
@immutable
class ScreenExposure {
  const ScreenExposure({required this.h, required this.s});

  /// Escape count lit at half brightness.
  final double h;

  /// Counts per halving of brightness past [h].
  final double s;
}

/// Fit the screen exposure to a `width × height` raster of escape counts
/// (non-escaping pixels hold [maxIterations]): `h` midway between the
/// [kExposureQuantile] and `1 − kExposureQuantile` counts of the smooth pixels
/// (of all escaping pixels if none is smooth), `s` such that those two are lit
/// [kExposureBand] and `1 − kExposureBand`, never below [kExposureMinSlope].
///
/// Returns null when no pixel escapes: there is nothing to expose for.
///
/// The quantiles interpolate linearly between order statistics, as the film's
/// `numpy.percentile` does, so both fit the same frame identically.
ScreenExposure? screenExposure(
  Uint32List counts,
  int width,
  int height,
  int maxIterations,
) {
  assert(counts.length == width * height, 'raster size mismatch');
  // Counting sort: counts are bounded by maxIterations, so two histograms
  // (smooth pixels, all escaping pixels) replace sorting millions of pixels.
  final Int32List smooth = Int32List(maxIterations);
  final Int32List escaping = Int32List(maxIterations);
  int smoothTotal = 0;
  int escapingTotal = 0;
  for (int y = 0; y < height; y++) {
    final int row = y * width;
    for (int x = 0; x < width; x++) {
      final int i = row + x;
      final int n = counts[i];
      if (n >= maxIterations) continue;
      escaping[n]++;
      escapingTotal++;
      if (x > 0 && (counts[i - 1] - n).abs() > kExposureSmooth) continue;
      if (x + 1 < width && (counts[i + 1] - n).abs() > kExposureSmooth) {
        continue;
      }
      if (y > 0 && (counts[i - width] - n).abs() > kExposureSmooth) continue;
      if (y + 1 < height && (counts[i + width] - n).abs() > kExposureSmooth) {
        continue;
      }
      smooth[n]++;
      smoothTotal++;
    }
  }
  final Int32List pool = smoothTotal > 0 ? smooth : escaping;
  final int total = smoothTotal > 0 ? smoothTotal : escapingTotal;
  if (total == 0) return null;

  final double lo = _quantile(pool, total, kExposureQuantile);
  final double hi = _quantile(pool, total, 1 - kExposureQuantile);
  final double span =
      2 * math.log(kExposureBand / (1 - kExposureBand)) / math.ln2;
  return ScreenExposure(
    h: (lo + hi) / 2,
    s: math.max((hi - lo) / span, kExposureMinSlope),
  );
}

/// The [q]-quantile of the [total] values a histogram holds, interpolated
/// linearly between the order statistics around rank `q · (total − 1)`.
double _quantile(Int32List histogram, int total, double q) {
  final double rank = q * (total - 1);
  final int below = rank.floor();
  final int a = _orderStatistic(histogram, below);
  final int b = below + 1 < total ? _orderStatistic(histogram, below + 1) : a;
  return a + (rank - below) * (b - a);
}

/// The value at 0-based [rank] in the sorted multiset a histogram holds.
int _orderStatistic(Int32List histogram, int rank) {
  int seen = 0;
  for (int v = 0; v < histogram.length; v++) {
    seen += histogram[v];
    if (seen > rank) return v;
  }
  return histogram.length - 1;
}
