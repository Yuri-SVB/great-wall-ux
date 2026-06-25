import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:great_wall_ux/great_wall_ux.dart';

Widget _host(int value, ValueChanged<int> onChanged) => MaterialApp(
  home: Scaffold(
    body: StageCountSlider(value: value, onChanged: onChanged),
  ),
);

void main() {
  group('StageCountSlider (9 positions, 0..8)', () {
    test('cap and per-stage constants match the protocol', () {
      expect(StageCountSlider.kMaxStages, 8); // 9 positions: 0..8
      expect(StageCountSlider.kWordsPerStage, 3);
      expect(StageCountSlider.kBitsPerStage, 32);
      // The cap lands on 24 words / 256 bits.
      expect(StageCountSlider.kMaxStages * StageCountSlider.kWordsPerStage, 24);
      expect(StageCountSlider.kMaxStages * StageCountSlider.kBitsPerStage, 256);
    });

    testWidgets('renders a discrete slider with 8 divisions (9 stops)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(4, (_) {}));
      final Slider slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, 0);
      expect(slider.max, 8);
      expect(slider.divisions, 8);
      expect(slider.value, 4);
      expect(find.text('Number of stages'), findsOneWidget);
    });

    testWidgets('value 0 reads as Stage-0 text only', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(0, (_) {}));
      expect(find.text('Stage-0 text only'), findsOneWidget);
    });

    testWidgets('value 8 summarises words and bits', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(8, (_) {}));
      expect(find.text('8 stages · 24 words · 256 bits'), findsOneWidget);
    });

    testWidgets('value 1 uses the singular "stage"', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(1, (_) {}));
      expect(find.text('1 stage · 3 words · 32 bits'), findsOneWidget);
    });

    testWidgets('dragging emits a snapped integer stage count', (
      WidgetTester tester,
    ) async {
      int? emitted;
      await tester.pumpWidget(_host(0, (int n) => emitted = n));
      await tester.drag(find.byType(Slider), const Offset(500, 0));
      await tester.pump();
      expect(emitted, isNotNull);
      expect(emitted, inInclusiveRange(0, 8));
    });
  });
}
