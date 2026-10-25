import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:great_wall_ux/src/canvas/canvas_painter.dart';

void main() {
  const int maxIter = 1024;

  group('packEscapeCountBytes', () {
    test('exact 16-bit counts: high byte in red, low byte in green', () {
      final Uint8List rgba = packEscapeCountBytes(
        Uint32List.fromList(<int>[0, 255, 256, 1023, 1024, 0xFFFF, 0x10000]),
      );
      List<int> px(int i) => rgba.sublist(i * 4, i * 4 + 4);
      expect(px(0), <int>[0, 0, 0, 255]);
      expect(px(1), <int>[0, 255, 0, 255]);
      expect(px(2), <int>[1, 0, 0, 255]);
      expect(px(3), <int>[3, 255, 0, 255]);
      expect(px(4), <int>[4, 0, 0, 255]);
      expect(px(5), <int>[255, 255, 0, 255]);
      expect(px(6), <int>[255, 255, 0, 255], reason: 'clamped to 16 bits');
    });

    test('the shader decode, 255 · (256·r + g), recovers every count', () {
      final Uint32List counts =
          Uint32List.fromList(<int>[for (int n = 0; n <= maxIter; n++) n]);
      final Uint8List rgba = packEscapeCountBytes(counts);
      for (int n = 0; n <= maxIter; n++) {
        final double r = rgba[n * 4] / 255.0;
        final double g = rgba[n * 4 + 1] / 255.0;
        expect((255.0 * (256.0 * r + g) + 0.5).floor(), n);
      }
    });
  });
}
