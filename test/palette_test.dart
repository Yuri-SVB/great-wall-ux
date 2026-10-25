import 'package:flutter_test/flutter_test.dart';
import 'package:great_wall_ux/great_wall_ux.dart';

int _r(int rgba) => (rgba >> 24) & 0xFF;
int _g(int rgba) => (rgba >> 16) & 0xFF;
int _b(int rgba) => (rgba >> 8) & 0xFF;
int _a(int rgba) => rgba & 0xFF;

void main() {
  group('Palette (single hue × 6, brightness-ramped)', () {
    test('exactly six hues at 60° spacing', () {
      expect(HueOffset.values, hasLength(6));
      final List<int> degrees =
          HueOffset.values.map((HueOffset h) => h.degrees).toList();
      expect(degrees, <int>[0, 60, 120, 180, 240, 300]);
    });

    test('default scheme is green', () {
      expect(kDefaultHue, HueOffset.green);
      expect(Palette.green.hueOffset, HueOffset.green);
      expect(Palette.green.id, 'hue-green');
      expect(Palette.green.size, 256);
    });

    test('forHue produces stable, distinct LUTs', () {
      // Reflexive
      final Palette a = Palette.forHue(HueOffset.blue);
      final Palette b = Palette.forHue(HueOffset.blue);
      for (int i = 0; i < a.size; i++) {
        expect(b.rgbaForIteration(i), a.rgbaForIteration(i));
      }
      // Different hues differ in their middle bands.
      final Palette green = Palette.forHue(HueOffset.green);
      expect(
        a.rgbaForIteration(a.size ~/ 2),
        isNot(green.rgbaForIteration(green.size ~/ 2)),
      );
    });

    test('inside index is opaque black for every hue', () {
      const int insideBlack = 0x000000FF;
      for (final HueOffset h in HueOffset.values) {
        final Palette p = Palette.forHue(h);
        expect(p.rgbaForIteration(p.size - 1), insideBlack);
      }
    });

    test('hue is constant within a scheme — green is pure green', () {
      // Green (120°) at full saturation has zero red and blue across every
      // escaping entry.
      final Palette p = Palette.forHue(HueOffset.green);
      for (int i = 0; i < p.size - 1; i++) {
        final int c = p.rgbaForIteration(i);
        expect(_r(c), 0, reason: 'red must stay 0 at index $i');
        expect(_b(c), 0, reason: 'blue must stay 0 at index $i');
        expect(_a(c), 0xFF);
      }
    });

    test('every escaping entry is the full-bright hue (no ramp)', () {
      // Brightness comes from the shader's falloff alone, which decreases with
      // the escape count; a palette ramping up with the count would make the
      // product rise and then fall.
      for (final HueOffset h in HueOffset.values) {
        final Palette p = Palette.forHue(h);
        final int full = p.rgbaForIteration(0);
        for (int i = 0; i < p.size - 1; i++) {
          expect(p.rgbaForIteration(i), full, reason: '$h index $i');
        }
      }
      expect(_g(Palette.green.rgbaForIteration(0)), 255);
    });

    test('out-of-range iterations clamp', () {
      final Palette p = Palette.green;
      expect(p.rgbaForIteration(-1), p.rgbaForIteration(0));
      expect(p.rgbaForIteration(1 << 30), p.rgbaForIteration(p.size - 1));
    });
  });
}
