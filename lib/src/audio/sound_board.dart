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

/// Plays the bundled UI sound cues, with a mute flag.
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
  SoundBoard({bool muted = false}) : _muted = muted {
    for (final UiSound s in UiSound.values) {
      final AudioPlayer player = AudioPlayer()
        ..setReleaseMode(ReleaseMode.stop)
        // Resolve assets relative to this package, not the consuming app.
        ..audioCache = AudioCache(prefix: _assetPrefix);
      // Pre-resolve the bundled asset so the first play is not delayed.
      unawaited(_safe(() => player.setSource(_sourceFor(s))));
      _players[s] = player;
    }
  }

  /// Cache prefix that points at this package's bundled assets. Combined with
  /// the per-cue path below it yields `packages/great_wall_ux/assets/sounds/…`.
  static const String _assetPrefix = 'packages/great_wall_ux/assets/';

  static AssetSource _sourceFor(UiSound s) => AssetSource('sounds/${s.asset}');

  final Map<UiSound, AudioPlayer> _players = <UiSound, AudioPlayer>{};

  bool _muted;

  /// Whether cues are currently suppressed.
  bool get muted => _muted;
  set muted(bool value) => _muted = value;

  /// Flip mute state; returns the new value.
  bool toggleMute() => _muted = !_muted;

  /// Play [sound], unless muted. Never throws.
  void play(UiSound sound) {
    if (_muted) return;
    final AudioPlayer? player = _players[sound];
    if (player == null) return;
    unawaited(_safe(() async {
      await player.stop();
      await player.play(_sourceFor(sound));
    }));
  }

  /// Release the underlying players.
  Future<void> dispose() async {
    for (final AudioPlayer p in _players.values) {
      await _safe(p.dispose);
    }
    _players.clear();
  }

  static Future<void> _safe(Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      // Audio is best-effort, display-only feedback: never let a cue failure
      // surface to the user or interrupt interaction.
      if (kDebugMode) {
        debugPrint('SoundBoard: cue suppressed ($e)');
      }
    }
  }
}
