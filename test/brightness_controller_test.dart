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
      c.adjustSlopeBySteps(7);
      c.reset();
      expect(c.offset, kDefaultBrightnessOffset);
      expect(c.slope, kDefaultBrightnessSlope);
    });

    test('slope starts at the original curve', () {
      final BrightnessController c = BrightnessController();
      expect(c.slope, kDefaultBrightnessSlope);
      expect(kDefaultBrightnessSlope, 1.0);
    });

    test('a doubling worth of slope steps doubles or halves it', () {
      final BrightnessController c = BrightnessController();
      c.adjustSlopeBySteps(kBrightnessSlopeStepsPerDoubling);
      expect(c.slope, closeTo(2.0 * kDefaultBrightnessSlope, 1e-12));
      c.adjustSlopeBySteps(-2 * kBrightnessSlopeStepsPerDoubling);
      expect(c.slope, closeTo(0.5 * kDefaultBrightnessSlope, 1e-12));
    });

    test('slope stays positive however far it is lowered', () {
      final BrightnessController c = BrightnessController();
      c.adjustSlopeBySteps(-1000);
      expect(c.slope, greaterThan(0.0));
    });

    test('slope steps leave the offset alone, and vice versa', () {
      final BrightnessController c = BrightnessController();
      c.adjustSlopeBySteps(3);
      expect(c.offset, kDefaultBrightnessOffset);
      final double s = c.slope;
      c.adjustBySteps(3);
      expect(c.slope, s);
    });

    test('notifies listeners only on actual change', () {
      final BrightnessController c = BrightnessController();
      int notifications = 0;
      c.addListener(() => notifications++);
      c.adjustBySteps(1);
      expect(notifications, 1);
      c.adjustBySteps(0); // no-op
      expect(notifications, 1);
      c.adjustSlopeBySteps(1);
      expect(notifications, 2);
      c.adjustSlopeBySteps(0); // no-op
      expect(notifications, 2);
    });
  });
}
