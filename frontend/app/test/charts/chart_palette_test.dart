import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(ChartPalette, () {
    test('carries the values measured from the design', () {
      // The two the informal token list got wrong, pinned so a future edit
      // has to argue with the measurement rather than with a memory.
      expect(ChartTokens.dark.surface, const Color(0xFF15161C));
      expect(ChartTokens.dark.barNeutral, const Color(0xFF6F7280));
      // …and the three it got right.
      expect(ChartTokens.dark.barGain, const Color(0xFF4ADE9E));
      expect(ChartTokens.dark.barLoss, const Color(0xFFFF6B5E));
      expect(ChartTokens.dark.barTotal, const Color(0xFF7A83FF));
    });

    test('gives light and dark different marks', () {
      expect(ChartTokens.light.barGain, isNot(ChartTokens.dark.barGain));
      expect(ChartTokens.light, isNot(equals(ChartTokens.dark)));
    });

    test('picks a palette by brightness', () {
      expect(ChartTokens.forBrightness(Brightness.light), ChartTokens.light);
      expect(ChartTokens.forBrightness(Brightness.dark), ChartTokens.dark);
    });

    test('is equal to a palette with the same colours', () {
      expect(ChartTokens.light, equals(ChartTokens.light.copyWith()));
      expect(ChartTokens.light.hashCode, ChartTokens.light.copyWith().hashCode);
      expect(ChartTokens.light, equals(ChartTokens.light));
    });

    test('copyWith replaces every colour it is given', () {
      const replaced = Color(0xFF00FF00);
      final changed = ChartTokens.light.copyWith(
        surface: replaced,
        border: replaced,
        title: replaced,
        barNeutral: replaced,
        barGain: replaced,
        barLoss: replaced,
        barTotal: replaced,
        connector: replaced,
        rule: replaced,
        mutedLabel: replaced,
      );
      expect(
        changed,
        equals(
          const ChartPalette(
            surface: replaced,
            border: replaced,
            title: replaced,
            barNeutral: replaced,
            barGain: replaced,
            barLoss: replaced,
            barTotal: replaced,
            connector: replaced,
            rule: replaced,
            mutedLabel: replaced,
          ),
        ),
      );
    });

    test('lerp returns itself when there is nothing to interpolate to', () {
      expect(ChartTokens.light.lerp(null, 0.5), same(ChartTokens.light));
    });

    test('lerp reaches each end of the interpolation', () {
      expect(ChartTokens.light.lerp(ChartTokens.dark, 0), ChartTokens.light);
      expect(ChartTokens.light.lerp(ChartTokens.dark, 1), ChartTokens.dark);
    });

    test('is on both themes, so a chart never invents a colour', () {
      expect(AppTheme.light.extension<ChartPalette>(), ChartTokens.light);
      expect(AppTheme.dark.extension<ChartPalette>(), ChartTokens.dark);
    });

    testWidgets('is readable from the tree in either brightness', (
      tester,
    ) async {
      // `MaterialApp` animates a theme change, so the first frame carries a
      // lerped palette; settling is what makes the comparison meaningful.
      for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
        late ChartPalette read;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                read = ChartPalette.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          read.barGain,
          ChartTokens.forBrightness(theme.brightness).barGain,
        );
        expect(
          read.surface,
          ChartTokens.forBrightness(theme.brightness).surface,
        );
      }
    });
  });
}
