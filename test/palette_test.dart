import 'package:flutter_test/flutter_test.dart';
import 'package:great_wall_ux/great_wall_ux.dart';

void main() {
  group('Palette (Classic × 6 hue rotations)', () {
    test('exactly six rotations at 60° spacing', () {
      expect(HueOffset.values, hasLength(6));
      final List<int> degrees =
          HueOffset.values.map((HueOffset h) => h.degrees).toList();
      expect(degrees, <int>[0, 60, 120, 180, 240, 300]);
    });

    test('Palette.classic is the red rotation', () {
      expect(Palette.classic.hueOffset, HueOffset.red);
      expect(Palette.classic.id, 'classic');
      expect(Palette.classic.size, 256);
    });

    test('classicWithHue produces stable, distinct LUTs', () {
      // Reflexive
      final Palette a = Palette.classicWithHue(HueOffset.blue);
      final Palette b = Palette.classicWithHue(HueOffset.blue);
      for (int i = 0; i < a.size; i++) {
        expect(b.rgbaForIteration(i), a.rgbaForIteration(i));
      }
      // Different rotations differ in their middle bands.
      final Palette red = Palette.classicWithHue(HueOffset.red);
      expect(
        a.rgbaForIteration(a.size ~/ 2),
        isNot(red.rgbaForIteration(red.size ~/ 2)),
      );
    });

    test('inside index is preserved across all rotations', () {
      // Last entry of the LUT is the "did not escape" colour. The Classic
      // base sets it to opaque black; hue rotation must not touch it.
      const int insideBlack = 0x000000FF;
      for (final HueOffset h in HueOffset.values) {
        final Palette p = Palette.classicWithHue(h);
        expect(p.rgbaForIteration(p.size - 1), insideBlack);
      }
    });

    test('out-of-range iterations clamp', () {
      final Palette p = Palette.classic;
      expect(p.rgbaForIteration(-1), p.rgbaForIteration(0));
      expect(p.rgbaForIteration(1 << 30), p.rgbaForIteration(p.size - 1));
    });
  });
}
