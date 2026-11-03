import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'sound_cues.dart';

export 'sound_cues.dart';

/// A sound-cue theme — a directory of wavs under `assets/sounds/`. Each theme
/// supplies a file for every [UiSound]; swapping a cue is just replacing its
/// wav, and adding a theme is just adding a sibling directory (plus a value
/// here and a pubspec entry). Theme *selection* is deferred — [SoundBoard]
/// defaults to [sober] for now.
enum SoundTheme {
  /// The default, restrained cue set.
  sober('sober');

  const SoundTheme(this.dir);

  /// Subdirectory under `assets/sounds/` holding this theme's wavs.
  final String dir;
}

/// The UI sound cues — the full vocabulary of events the app can voice. Short,
/// synthesised "futuristic console" blips in the spirit of late-90s RTS
/// interfaces — tactile feedback for the "sober, but game-like" surface
/// (`great-wall-docs/great-wall-ux/SCOPE.md`).
///
/// Each cue is its own wav, so a cue is changed by simply replacing its file in
/// the active theme directory. The first cut ships every cue as a copy of one
/// of the four base primitives (click / select / confirm / deny); they are
/// meant to diverge over time — that's the point of giving each its own file.
/// The consuming app maps its events onto these (see the wallet setup screen).
enum UiSound {
  // --- Base primitives -------------------------------------------------------
  /// Generic tap / click (canvas tap, neutral UI press).
  click('click.wav'),

  /// A reference point was committed (generic affirmative selection).
  select('select.wav'),

  /// A stage decode/encode completed (generic success).
  confirm('confirm.wav'),

  /// A rejected / invalid action (generic negative).
  deny('deny.wav'),

  // --- Errors / negatives (copies of deny) -----------------------------------
  /// Action blocked by a precondition (prior stage lacks a point; stage not yet
  /// reachable; "recall the earlier stages first").
  denyBlocked('deny_blocked.wav'),

  /// Not an error, just not yet — inter-stage hashing still running.
  denyPending('deny_pending.wav'),

  /// A selected point fell where no encodable leaf exists (contracted-away
  /// area).
  denyMiss('deny_miss.wav'),

  /// Invalid text input (should be a number; generic invalid).
  denyInput('deny_input.wav'),

  /// A destructive confirmation is being raised (abort / reset dialog).
  warn('warn.wav'),

  /// A stage / action was removed or undone (tbd feature).
  undo('undo.wav'),

  // --- Soft ticks / UI / directional (copies of click) -----------------------
  /// Very soft "digital interface" tick: a regular keystroke or a corrected
  /// input.
  tickSoft('tick_soft.wav'),

  /// A field took keyboard focus.
  focus('focus.wav'),

  /// Pan / slide of the canvas.
  slide('slide.wav'),

  /// A "more" adjustment: volume up, zoom in, brightness up.
  adjustUp('adjust_up.wav'),

  /// A "less" adjustment: volume down, zoom out, brightness down.
  adjustDown('adjust_down.wav'),

  /// Chrome expanded / maximized.
  chromeUp('chrome_up.wav'),

  /// Chrome minimized.
  chromeDown('chrome_down.wav'),

  /// Top-level mode navigation (F1–F5).
  navMode('nav_mode.wav'),

  /// A toggle turned off (e.g. fast render — deep mode off).
  modeOff('mode_off.wav'),

  // --- Navigation / selection (copies of select) -----------------------------
  /// Moved to a stage (entered stage 0 or a fractal stage).
  navStage('nav_stage.wav'),

  /// Canonical zoom onto a stage's point.
  navZoom('nav_zoom.wav'),

  /// A point was selected.
  selectPoint('select_point.wav'),

  /// The selected point was changed (re-selected).
  changePoint('change_point.wav'),

  /// A toggle turned on (e.g. deep render mode on).
  modeOn('mode_on.wav'),

  // --- Success / ready (copies of confirm) -----------------------------------
  /// A new stage became ready (derived).
  stageReady('stage_ready.wav'),

  /// The final stage / full recall completed.
  finalReady('final_ready.wav'),

  /// A new intermediary digest became ready (tbd wiring).
  digestReady('digest_ready.wav'),

  /// A secret was exported to the clipboard (master secret / mnemonic).
  exportOk('export_ok.wav');

  const UiSound(this.asset);

  /// Asset filename under `assets/sounds/<theme>/` in this package.
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

/// Plays the UI sound cues by name, through a soft-coded [SoundCueMap], with
/// a discrete volume control.
///
/// A cue is played by name ([cue]); a [UiSound] is the cue of the same name
/// ([play]). The map says which file each name plays, how loud, and how often
/// at most; it starts as [SoundCueMap.defaults] and can be replaced at run
/// time ([applyCues]), its files taken from a folder of the app's choosing
/// before the bundled ones — so cues are swapped without a rebuild.
///
/// Volume is an integer level from 0 ([kMaxVolumeLevel] steps). **Level 0 is
/// silent and is exactly what "muted" means** — there is no separate mute
/// flag; [muted] is simply `volumeLevel == 0`, and [toggleMute] drops to 0 and
/// restores the prior level. The level maps linearly onto the underlying
/// 0.0–1.0 player gain, scaled by each cue's loudness.
///
/// Resilient by construction: cues are display-only feedback, so any audio
/// error (no device, plugin unavailable on a platform, missing file) is
/// swallowed and the board falls back to silence rather than disturbing the
/// interaction. The cues carry no coordinate data and are never logged —
/// consistent with the library's no-leak posture.
///
/// One [AudioPlayer] per file and loudness lets short blips overlap without
/// one cutting another off. Construct once per session and [dispose] when
/// done.
class SoundBoard {
  SoundBoard({
    bool muted = false,
    int volumeLevel = kMaxVolumeLevel,
    this.theme = SoundTheme.sober,
  })  : _level = muted ? 0 : volumeLevel.clamp(0, kMaxVolumeLevel),
        // Restore target for unmute — never 0, so unmuting always makes sound.
        _preMuteLevel = volumeLevel.clamp(1, kMaxVolumeLevel) {
    applyCues(SoundCueMap.defaults);
  }

  /// The active cue theme: where the bundled files live,
  /// `assets/sounds/<theme.dir>/`.
  final SoundTheme theme;

  /// Cache prefix that points at this package's bundled assets. Combined with
  /// the per-file path below it yields `packages/great_wall_ux/assets/sounds/…`.
  static const String _assetPrefix = 'packages/great_wall_ux/assets/';

  /// The files bundled with every theme: one per [UiSound].
  static final Set<String> bundledFiles = <String>{
    for (final UiSound s in UiSound.values) s.asset,
  };

  SoundCueMap _cues = SoundCueMap(const <String, SoundCue>{});
  Map<String, String> _localFiles = const <String, String>{};
  final CueGate _gate = CueGate();

  /// Players by source and loudness, with the loudness they play at.
  final Map<String, ({AudioPlayer player, double loudness})> _players =
      <String, ({AudioPlayer player, double loudness})>{};

  /// The cue map in effect.
  SoundCueMap get cues => _cues;

  /// Use [map] from now on. [localFiles] maps a file name to its path on disk
  /// (the app's cue folder); those are played before the bundled files of the
  /// same name. Returns the files [map] names that neither provides — their
  /// cues stay silent.
  List<String> applyCues(
    SoundCueMap map, {
    Map<String, String> localFiles = const <String, String>{},
  }) {
    _cues = map;
    _localFiles = Map<String, String>.of(localFiles);
    final List<String> missing = <String>[];
    final Set<String> keep = <String>{};
    for (final SoundCue c in map.entries.values) {
      final String? file = c.file;
      if (file == null) continue;
      final Source? source = _sourceFor(file);
      if (source == null) {
        if (!missing.contains(file)) missing.add(file);
        continue;
      }
      final String key = _key(file, c.loudness);
      keep.add(key);
      if (_players.containsKey(key)) {
        // A local file may have changed on disk: load it afresh.
        if (_localFiles.containsKey(file)) {
          unawaited(
            _safe(
              () => _players[key]!.player.setSource(source),
              label: 'reload $file',
            ),
          );
        }
        continue;
      }
      final AudioPlayer player = AudioPlayer()
        ..setReleaseMode(ReleaseMode.stop)
        // Resolve assets relative to this package, not the consuming app.
        ..audioCache = AudioCache(prefix: _assetPrefix);
      // Pre-resolve the source so the first play is not delayed.
      unawaited(_safe(() => player.setSource(source), label: 'preload $file'));
      unawaited(
        _safe(
          () => player.setVolume(_gain * c.loudness),
          label: 'volume $file',
        ),
      );
      _players[key] = (player: player, loudness: c.loudness);
    }
    for (final String key in _players.keys.toList()) {
      if (keep.contains(key)) continue;
      final AudioPlayer p = _players.remove(key)!.player;
      unawaited(_safe(p.dispose, label: 'dispose $key'));
    }
    return missing;
  }

  String _key(String file, double loudness) => '$file@$loudness';

  Source? _sourceFor(String file) {
    final String? local = _localFiles[file];
    if (local != null) return DeviceFileSource(local);
    if (bundledFiles.contains(file)) {
      return AssetSource('sounds/${theme.dir}/$file');
    }
    return null;
  }

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
    for (final ({AudioPlayer player, double loudness}) p in _players.values) {
      unawaited(
        _safe(
          () => p.player.setVolume(gain * p.loudness),
          label: 'setVolume',
        ),
      );
    }
    return _level;
  }

  /// Play [sound]: the cue of the same name. Never throws.
  void play(UiSound sound) => cue(sound.name);

  /// Play the cue called [name] (see [SoundCueMap.resolve]), unless the board
  /// is silent, the cue is, or it played less than its minimum gap ago. Never
  /// throws.
  void cue(String name) {
    if (_level == 0) return;
    final ({String name, SoundCue cue})? line = _cues.resolve(name);
    final String? file = line?.cue.file;
    if (line == null || file == null) return;
    if (!_gate.allow(line.name, line.cue.minGap)) return;
    final AudioPlayer? player = _players[_key(file, line.cue.loudness)]?.player;
    if (player == null) return;
    // Replay the already-loaded source: rewind then resume. This is the
    // low-latency desktop pattern and avoids re-preparing the GStreamer
    // pipeline on every cue (which on Linux could swallow the playback).
    unawaited(_safe(
      () async {
        await player.seek(Duration.zero);
        await player.resume();
      },
      label: 'play $file',
    ));
  }

  /// Release the underlying players.
  Future<void> dispose() async {
    for (final ({AudioPlayer player, double loudness}) p in _players.values) {
      await _safe(p.player.dispose);
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
