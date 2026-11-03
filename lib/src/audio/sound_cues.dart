/// Soft-coded sound cues: a plain-text map from cue names to sound files,
/// read at run time, so cues can be swapped without a rebuild.
///
/// The map is a table, one cue per line, `#` starting a comment:
///
/// ```text
/// # cue               file              loudness  min gap (ms)
/// press               click.wav         0.6
/// hover               tick_soft.wav     0.3       80
/// press.setup.dice    -                           # silent
/// ```
///
/// Names are dotted; a name without its own line falls back to its parent
/// (`press.setup.dice` → `press.setup` → `press`), and a name with no line
/// anywhere on that chain is silent. A file of `-` silences a cue (and
/// everything that falls back to it). Loudness (0–1, default 1) scales the
/// board's volume; the minimum gap (default 0) drops repeats of the same
/// line that come sooner — for cues fired in bursts, such as hover and
/// scroll-zoom.
///
/// Cues must never depend on secret content (which digit was typed, where a
/// point lies): a sound is heard by anyone nearby.
library;

/// The cues this library plays itself: zooming the canvas by scrolling.
const String kCueZoomIn = 'zoom.in';
const String kCueZoomOut = 'zoom.out';

/// One line of the map: the file it plays (null: silent), how loud, and the
/// shortest gap between two plays.
class SoundCue {
  const SoundCue(this.file, {this.loudness = 1, this.minGap = Duration.zero});

  /// The sound file's name, or null for silence.
  final String? file;

  /// Scales the board's volume, 0 to 1.
  final double loudness;

  /// Repeats of this line sooner than this are dropped.
  final Duration minGap;

  @override
  bool operator ==(Object other) =>
      other is SoundCue &&
      other.file == file &&
      other.loudness == loudness &&
      other.minGap == minGap;

  @override
  int get hashCode => Object.hash(file, loudness, minGap);
}

/// A problem with one line of a cue map; that line is skipped.
class SoundCueError {
  const SoundCueError(this.line, this.message);

  /// 1-based line number.
  final int line;
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// The cue map: names to [SoundCue]s, with dotted fallback.
class SoundCueMap {
  SoundCueMap(Map<String, SoundCue> entries)
      : entries = Map<String, SoundCue>.unmodifiable(entries);

  final Map<String, SoundCue> entries;

  /// The file name meaning silence.
  static const String silent = '-';

  /// Characters a cue name may use.
  static final RegExp _name = RegExp(r'^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)*$');

  /// Parse [text]. Bad lines are skipped and reported in [errors].
  static SoundCueMap parse(String text, {List<SoundCueError>? errors}) {
    final Map<String, SoundCue> out = <String, SoundCue>{};
    final List<String> lines = text.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final int n = i + 1;
      final int hash = lines[i].indexOf('#');
      final String body = (hash < 0 ? lines[i] : lines[i].substring(0, hash)).trim();
      if (body.isEmpty) continue;
      final List<String> t = body.split(RegExp(r'\s+'));
      if (t.length < 2 || t.length > 4) {
        errors?.add(SoundCueError(n, 'expected: cue file [loudness] [min gap ms]'));
        continue;
      }
      if (!_name.hasMatch(t[0])) {
        errors?.add(SoundCueError(n, 'bad cue name "${t[0]}"'));
        continue;
      }
      double loudness = 1;
      if (t.length > 2) {
        final double? v = double.tryParse(t[2]);
        if (v == null || v < 0 || v > 1) {
          errors?.add(SoundCueError(n, 'loudness must be 0 to 1'));
          continue;
        }
        loudness = v;
      }
      Duration gap = Duration.zero;
      if (t.length > 3) {
        final int? ms = int.tryParse(t[3]);
        if (ms == null || ms < 0) {
          errors?.add(SoundCueError(n, 'min gap must be whole milliseconds'));
          continue;
        }
        gap = Duration(milliseconds: ms);
      }
      out[t[0]] = SoundCue(
        t[1] == silent ? null : t[1],
        loudness: loudness,
        minGap: gap,
      );
    }
    return SoundCueMap(out);
  }

  /// The line [name] plays: its own, else its nearest dotted parent's; null
  /// when none is on the chain. Returns the line's name with it.
  ({String name, SoundCue cue})? resolve(String name) {
    String n = name;
    while (true) {
      final SoundCue? c = entries[n];
      if (c != null) return (name: n, cue: c);
      final int dot = n.lastIndexOf('.');
      if (dot < 0) return null;
      n = n.substring(0, dot);
    }
  }

  /// This map with [over]'s lines on top.
  SoundCueMap overlaidWith(SoundCueMap over) =>
      SoundCueMap(<String, SoundCue>{...entries, ...over.entries});

  /// The files the map plays.
  Set<String> get files => <String>{
        for (final SoundCue c in entries.values)
          if (c.file != null) c.file!,
      };

  /// The built-in defaults: every [UiSound] by its name, and the families
  /// the app voices (button press and hover, alerts, dialogs, function keys,
  /// zoom), whose placeholders reuse those same files.
  static final SoundCueMap defaults = parse(defaultText);

  /// [defaults] as text — what an app writes out for the user to edit.
  static const String defaultText = '''
# Great Wall sound cues. One cue per line:
#
#   cue                file               [loudness 0-1]  [min gap ms]
#
# A cue without its own line falls back to its parent:
# press.setup.dice -> press.setup -> press. A file of "-" silences a cue.
# Files are looked up in this folder first, then among the built-in sounds.
# Save this file (or drop in a sound file) and the app reloads it.

# --- Button press and hover -------------------------------------------------
press                click.wav          0.6
hover                tick_soft.wav      0.3   80

# --- Alerts and dialogs ------------------------------------------------------
alert                warn.wav
dialog.open          chrome_up.wav
dialog.close         chrome_down.wav

# --- Function keys -----------------------------------------------------------
key.f1.collapse      chrome_down.wav
key.f1.restore       chrome_up.wav
key.f2               nav_mode.wav
key.f3               deny.wav
key.f4               deny.wav
key.f5               deny.wav

# --- Zoom by scrolling -------------------------------------------------------
zoom.in              adjust_up.wav      0.5   120
zoom.out             adjust_down.wav    0.5   120

# --- Events ------------------------------------------------------------------
click                click.wav
select               select.wav
confirm              confirm.wav
deny                 deny.wav
denyBlocked          deny_blocked.wav
denyPending          deny_pending.wav
denyMiss             deny_miss.wav
denyInput            deny_input.wav
warn                 warn.wav
undo                 undo.wav
tickSoft             tick_soft.wav
focus                focus.wav
slide                slide.wav
adjustUp             adjust_up.wav
adjustDown           adjust_down.wav
chromeUp             chrome_up.wav
chromeDown           chrome_down.wav
navMode              nav_mode.wav
modeOff              mode_off.wav
navStage             nav_stage.wav
navZoom              nav_zoom.wav
selectPoint          select_point.wav
changePoint          change_point.wav
modeOn               mode_on.wav
stageReady           stage_ready.wav
finalReady           final_ready.wav
digestReady          digest_ready.wav
exportOk             export_ok.wav
''';
}

/// Drops repeats of a line that come sooner than its [SoundCue.minGap].
class CueGate {
  CueGate({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, DateTime> _last = <String, DateTime>{};

  /// Whether line [name] may play now; if so, it counts as played.
  bool allow(String name, Duration minGap) {
    final DateTime now = _clock();
    final DateTime? last = _last[name];
    if (minGap > Duration.zero &&
        last != null &&
        now.difference(last) < minGap) {
      return false;
    }
    _last[name] = now;
    return true;
  }
}
