import 'package:finance_app/components/scenario_comparison/scenario_comparison_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(ScenarioComparisonTokens, () {
    /// The eight values, pinned.
    ///
    /// Read from the designer's rendered DOM with `getComputedStyle`, in
    /// both artboards — not from a hand-written token list. GGU-55 found two
    /// of five circulated values wrong because they had been taken from the
    /// bundle's placeholder thumbnail rather than the rendered page, so this
    /// suite pins every one of this card's.
    test('carries the light artboard, as measured', () {
      const light = ScenarioComparisonTokens.light;
      expect(light.caption, const Color(0xFF8A8D96));
      expect(light.metricLabel, const Color(0xFF44464E));
      expect(light.rowRule, const Color(0xFFF0EDF5));
      expect(light.headerBorder, const Color(0xFFEAE7F0));
    });

    test('carries the dark artboard, as measured', () {
      const dark = ScenarioComparisonTokens.dark;
      expect(dark.caption, const Color(0xFF8A8D96));
      expect(dark.metricLabel, const Color(0xFFC9CBD4));
      expect(dark.rowRule, const Color(0xFF202128));
      expect(dark.headerBorder, const Color(0xFF2A2B33));
    });

    test('keeps the two values that are nearly ChartPalette, apart', () {
      // These are the pairs a reuse would have got wrong, and the reason
      // this card carries its own set: a row rule is not an axis rule, and
      // a header hairline is not a card hairline.
      expect(
        ScenarioComparisonTokens.light.rowRule,
        isNot(const Color(0xFFF0EEF5)),
      );
      expect(
        ScenarioComparisonTokens.dark.headerBorder,
        isNot(const Color(0xFF24252D)),
      );
    });

    test('keeps one neutral across both artboards', () {
      // The design does not re-tone its eyebrow for dark mode, and a
      // "surely it must" edit would be caught here.
      expect(
        ScenarioComparisonTokens.dark.caption,
        ScenarioComparisonTokens.light.caption,
      );
    });

    test('picks a set from a brightness', () {
      expect(
        ScenarioComparisonTokens.forBrightness(Brightness.dark),
        same(ScenarioComparisonTokens.dark),
      );
      expect(
        ScenarioComparisonTokens.forBrightness(Brightness.light),
        same(ScenarioComparisonTokens.light),
      );
    });

    testWidgets('reads the set matching the theme it is under', (tester) async {
      late ScenarioComparisonTokens seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Builder(
            builder: (context) {
              seen = ScenarioComparisonTokens.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen, same(ScenarioComparisonTokens.dark));
    });
  });
}
