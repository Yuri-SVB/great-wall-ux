import 'package:flutter_test/flutter_test.dart';
import 'package:great_wall_ux/great_wall_ux.dart';

void main() {
  group('BrightnessController', () {
    test('starts at the session default', () {
      final BrightnessController c = BrightnessController();
      expect(c.offset, kDefaultBrightnessOffset);
      expect(c.step, kBrightnessStep);
    });

    test('adjustBySteps moves by the fine 0.1 step', () {
      final BrightnessController c = BrightnessController();
      final double start = c.offset;
      c.adjustBySteps(1);
      expect(c.offset, closeTo(start + 0.1, 1e-12));
      c.adjustBySteps(-3);
      expect(c.offset, closeTo(start - 0.2, 1e-12));
    });

    test('reset returns to the default', () {
      final BrightnessController c = BrightnessController();
      c.adjustBySteps(10);
      c.reset();
      expect(c.offset, kDefaultBrightnessOffset);
    });

    test('notifies listeners only on actual change', () {
      final BrightnessController c = BrightnessController();
      int notifications = 0;
      c.addListener(() => notifications++);
      c.adjustBySteps(1);
      expect(notifications, 1);
      c.adjustBySteps(0); // no-op
      expect(notifications, 1);
    });
  });
}
