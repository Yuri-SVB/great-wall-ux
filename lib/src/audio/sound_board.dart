import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The UI sound cues. Short, synthesised "futuristic console" blips in the
/// spirit of late-90s RTS interfaces — tactile feedback for the
/// "sober, but game-like" surface (`great-wall-docs/great-wall-ux/SCOPE.md`).
enum UiSound {
  /// Any pointer tap on the canvas.
  click('click.wav'),

  /// A reference point was committed.
  select('select.wav'),

  /// A stage decode/encode completed.
  confirm('confirm.wav'),

  /// A rejected / invalid action.
  deny('deny.wav');

  const UiSound(this.asset);

  /// Asset filename under `assets/sounds/` in this package.
  final String asset;
}

/// Number of discrete volume steps the UI cues expose, above silence.
///
/// Level 0 is silent — functionally identical to muting the app — and
/// [kMaxVolumeLevel] is full volume, giving 11 settings (0..10). Ten steps is
/// the familiar media-player granularity: fine enough to dial in a comfortable
/// level, coarse enough to reach either end in about a second of holding the
/// `V` + arrow hotkey.
const int kMaxVolumeLevel = 10;

/// Plays the bundled UI sound cues, with a discrete volume control.
///
/// Volume is an integer level from 0 ([kMaxVolumeLevel] steps). **Level 0 is
/// silent and is exactly what "muted" means** — there is no separate mute
/// flag; [muted] is simply `volumeLevel == 0`, and [toggleMute] drops to 0 and
/// restores the prior level. The level maps linearly onto the underlying
/// 0.0–1.0 player gain.
///
/// Resilient by construction: cues are display-only feedback, so any audio
/// error (no device, plugin unavailable on a platform, asset hiccup) is
/// swallowed and the board falls back to silence rather than disturbing the
/// interaction. The cues carry no coordinate data and are never logged —
/// consistent with the library's no-leak posture.
///
/// One [AudioPlayer] per cue allows the short blips to overlap without one
/// cutting another off. Construct once per session and [dispose] when done.
class SoundBoard {
  SoundBoard({bool muted = false, int volumeLevel = kMaxVolumeLevel})
      : _level = muted ? 0 : volumeLevel.clamp(0, kMaxVolumeLevel),
        // Restore target for unmute — never 0, so unmuting always makes sound.
        _preMuteLevel = volumeLevel.clamp(1, kMaxVolumeLevel) {
    for (final UiSound s in UiSound.values) {
      final AudioPlayer player = AudioPlayer()
        ..setReleaseMode(ReleaseMode.stop)
        // Resolve assets relative to this package, not the consuming app.
        ..audioCache = AudioCache(prefix: _assetPrefix);
      // Pre-resolve the bundled asset so the first play is not delayed.
      unawaited(_safe(
        () => player.setSource(_sourceFor(s)),
        label: 'preload ${s.asset}',
      ));
      // Seed the player gain to the starting level.
      unawaited(_safe(
        () => player.setVolume(_gain),
        label: 'volume ${s.asset}',
      ));
      _players[s] = player;
    }
  }

  /// Cache prefix that points at this package's bundled assets. Combined with
  /// the per-cue path below it yields `packages/great_wall_ux/assets/sounds/…`.
  static const String _assetPrefix = 'packages/great_wall_ux/assets/';

  static AssetSource _sourceFor(UiSound s) => AssetSource('sounds/${s.asset}');

  final Map<UiSound, AudioPlayer> _players = <UiSound, AudioPlayer>{};

  /// Current volume level, 0..[kMaxVolumeLevel].
  int _level;

  /// Level to restore on unmute. Kept in sync with the last non-zero level so
  /// that toggling mute off returns to wherever the user last had it.
  int _preMuteLevel;

  /// Current volume level, from 0 (silent) to [kMaxVolumeLevel] (full).
  int get volumeLevel => _level;

  /// The 0.0–1.0 player gain for the current level.
  double get _gain => _level / kMaxVolumeLevel;

  /// Whether cues are currently silent. Muting *is* volume 0, so this is true
  /// iff [volumeLevel] is 0.
  bool get muted => _level == 0;

  /// Mute (true → volume 0) or restore the previous level (false).
  set muted(bool value) {
    if (value) {
      _mute();
    } else {
      _unmute();
    }
  }

  /// Flip mute state; returns the new value. Unmuting restores the level in
  /// effect before the last mute.
  bool toggleMute() {
    if (muted) {
      _unmute();
    } else {
      _mute();
    }
    return muted;
  }

  /// Raise the volume by one step (capped at [kMaxVolumeLevel]). Returns the
  /// new level.
  int volumeUp() => _applyLevel(_level + 1);

  /// Lower the volume by one step (floored at 0 — silent, i.e. muted). Returns
  /// the new level.
  int volumeDown() => _applyLevel(_level - 1);

  /// Set the volume to [level] (clamped to 0..[kMaxVolumeLevel]). Returns the
  /// new level.
  int setVolumeLevel(int level) => _applyLevel(level);

  void _mute() => _applyLevel(0);

  void _unmute() {
    if (_level == 0) _applyLevel(_preMuteLevel);
  }

  /// Clamp, store, and push [level] to every player. Remembers the last
  /// non-zero level as the unmute target. Returns the resulting level.
  int _applyLevel(int level) {
    final int clamped = level.clamp(0, kMaxVolumeLevel);
    if (clamped != 0) _preMuteLevel = clamped;
    if (clamped == _level) return _level;
    _level = clamped;
    final double gain = _gain;
    for (final AudioPlayer p in _players.values) {
      unawaited(_safe(() => p.setVolume(gain), label: 'setVolume'));
    }
    return _level;
  }

  /// Play [sound], unless silent (volume 0). Never throws.
  void play(UiSound sound) {
    if (_level == 0) return;
    final AudioPlayer? player = _players[sound];
    if (player == null) return;
    // Replay the already-loaded source: rewind then resume. This is the
    // low-latency desktop pattern and avoids re-preparing the GStreamer
    // pipeline on every cue (which on Linux could swallow the playback).
    unawaited(_safe(
      () async {
        await player.seek(Duration.zero);
        await player.resume();
      },
      label: 'play ${sound.asset}',
    ));
  }

  /// Release the underlying players.
  Future<void> dispose() async {
    for (final AudioPlayer p in _players.values) {
      await _safe(p.dispose);
    }
    _players.clear();
  }

  static Future<void> _safe(Future<void> Function() op, {String label = ''}) async {
    try {
      await op();
    } catch (e) {
      // Audio is best-effort, display-only feedback: never let a cue failure
      // surface to the user or interrupt interaction. Logged (debug only) so
      // a silent backend can still be diagnosed.
      if (kDebugMode) {
        debugPrint('SoundBoard: $label suppressed ($e)');
      }
    }
  }
}
