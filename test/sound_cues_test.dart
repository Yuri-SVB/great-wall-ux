import 'package:flutter_test/flutter_test.dart';
import 'package:great_wall_ux/great_wall_ux.dart';

/// The soft-coded cue map: parsing, dotted fallback, silence, defaults and
/// the repeat gate.
void main() {
  test('parses lines, comments, loudness and gap', () {
    final List<SoundCueError> errors = <SoundCueError>[];
    final SoundCueMap m = SoundCueMap.parse(
      '''
# a comment
press        click.wav   0.6
hover        tick.wav    0.3   80   # trailing comment

press.x.y    -
''',
      errors: errors,
    );
    expect(errors, isEmpty);
    expect(m.entries['press'], const SoundCue('click.wav', loudness: 0.6));
    expect(
      m.entries['hover'],
      const SoundCue(
        'tick.wav',
        loudness: 0.3,
        minGap: Duration(milliseconds: 80),
      ),
    );
    expect(m.entries['press.x.y'], const SoundCue(null));
    expect(m.files, <String>{'click.wav', 'tick.wav'});
  });

  test('bad lines are reported and skipped, the rest kept', () {
    final List<SoundCueError> errors = <SoundCueError>[];
    final SoundCueMap m = SoundCueMap.parse(
      '''
ok           a.wav
lonely
bad name     a.wav   1    2   3
loud         a.wav   1.5
gap          a.wav   1    -4
n@me         a.wav
''',
      errors: errors,
    );
    expect(m.entries.keys, <String>['ok']);
    expect(errors.map((SoundCueError e) => e.line), <int>[2, 3, 4, 5, 6]);
  });

  test('a name falls back to its nearest parent, else is silent', () {
    final SoundCueMap m = SoundCueMap.parse('''
press          click.wav
press.setup    setup.wav
press.main.x   -
''');
    expect(m.resolve('press.setup.dice')!.name, 'press.setup');
    expect(m.resolve('press.view.hue')!.name, 'press');
    expect(m.resolve('press.main.x')!.cue.file, isNull);
    expect(m.resolve('hover.setup'), isNull);
  });

  test('an overlay replaces lines and keeps the rest', () {
    final SoundCueMap m = SoundCueMap.defaults
        .overlaidWith(SoundCueMap.parse('press  mine.wav'));
    expect(m.entries['press']!.file, 'mine.wav');
    expect(m.entries['hover'], SoundCueMap.defaults.entries['hover']);
  });

  test('the defaults voice every UiSound with its own file', () {
    for (final UiSound s in UiSound.values) {
      expect(
        SoundCueMap.defaults.entries[s.name]?.file,
        s.asset,
        reason: s.name,
      );
    }
    final List<SoundCueError> errors = <SoundCueError>[];
    SoundCueMap.parse(SoundCueMap.defaultText, errors: errors);
    expect(errors, isEmpty);
    // Every default file is bundled.
    expect(
      SoundBoard.bundledFiles.containsAll(SoundCueMap.defaults.files),
      isTrue,
    );
    for (final String cue in <String>[kCueZoomIn, kCueZoomOut]) {
      expect(SoundCueMap.defaults.resolve(cue), isNotNull, reason: cue);
    }
  });

  test('the gate drops repeats sooner than the gap', () {
    DateTime now = DateTime(2026);
    final CueGate gate = CueGate(clock: () => now);
    const Duration gap = Duration(milliseconds: 80);
    expect(gate.allow('hover', gap), isTrue);
    now = now.add(const Duration(milliseconds: 50));
    expect(gate.allow('hover', gap), isFalse);
    expect(gate.allow('press', Duration.zero), isTrue);
    expect(gate.allow('press', Duration.zero), isTrue);
    now = now.add(const Duration(milliseconds: 40));
    expect(gate.allow('hover', gap), isTrue);
  });
}
