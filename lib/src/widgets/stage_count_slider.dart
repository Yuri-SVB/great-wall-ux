import 'package:flutter/material.dart';

/// A discrete slider for choosing the **number of chained stages**, from 0 to 8.
///
/// Nine positions (`0..8`) cover the protocol's full range: 0 selects a
/// Stage-0-text-only setup (no fractal stages), and 8 is the hard cap — 24
/// BIP39 words / 256 bits of entropy, the most stages the chained protocol
/// admits (`constants.MAX_ENTROPY_BITS`; see
/// `great-wall-docs/next-steps/chained-protocol-size-and-ux-roadmap.md` §1).
/// Each added stage is one fixed Argon2 iteration count's worth of marginal
/// effort, so the slider doubles as the "level-up" progression surface the
/// roadmap calls for (§6).
///
/// The control is deliberately discrete: a [Slider] with `divisions: 8` snaps
/// to the nine integer positions, so there is no ambiguous in-between state.
class StageCountSlider extends StatelessWidget {
  const StageCountSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.maxStages = kMaxStages,
  }) : assert(value >= 0 && value <= maxStages, 'stage count out of range');

  /// The hard cap on chained stages (24 words / 256 bits). Yields `maxStages
  /// + 1` slider positions, i.e. 9 for the default.
  static const int kMaxStages = 8;

  /// BIP39 words contributed per stage (32 bits ÷ 11 bits-per-word, rounded to
  /// the protocol's 3-words-per-stage granularity).
  static const int kWordsPerStage = 3;

  /// Entropy bits contributed per stage.
  static const int kBitsPerStage = 32;

  /// Currently selected number of stages, in `0..maxStages`.
  final int value;

  /// Called with the new stage count when the user drags or taps the slider.
  final ValueChanged<int> onChanged;

  /// Upper bound on the stage count; the slider runs `0..maxStages`.
  final int maxStages;

  @override
  Widget build(BuildContext context) {
    final int words = value * kWordsPerStage;
    final int bits = value * kBitsPerStage;
    final String summary = value == 0
        ? 'Stage-0 text only'
        : '$value ${value == 1 ? 'stage' : 'stages'} · $words words · $bits bits';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Number of stages',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Semantics(
          slider: true,
          label: 'Number of stages',
          value: '$value of $maxStages',
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: maxStages.toDouble(),
            divisions: maxStages,
            label: '$value',
            onChanged: (double v) {
              final int next = v.round();
              if (next != value) onChanged(next);
            },
          ),
        ),
        Text(
          summary,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
