import 'package:finance_app/charts/allocation_palette.dart';
import 'package:finance_app/charts/chart_extensions.dart';
import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/charts/payoff_palette.dart';
import 'package:finance_app/charts/payoff_tokens.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The seam that keeps `app_theme.dart` from growing once per chart.
///
/// ADR-L D-3 says adding a component edits no shared list. The component
/// registry honours that by generation, but the theme's `extensions:` list
/// did not: GGU-55 added `ChartTokens` to it and GGU-63 added `PayoffTokens`
/// — a chain forming one entry at a time. `chartExtensions` is where that
/// list lives now, beside the colours it is made of, and these tests are what
/// stop the two drifting (`specs/frontend/0005` OD-9).
void main() {
  group('chartExtensions', () {
    test('carries every chart palette, in both brightnesses', () {
      expect(chartExtensions(Brightness.light), <ThemeExtension<Object?>>[
        ChartTokens.light,
        ChartTokens.allocationLight,
        PayoffTokens.light,
      ]);
      expect(chartExtensions(Brightness.dark), <ThemeExtension<Object?>>[
        ChartTokens.dark,
        ChartTokens.allocationDark,
        PayoffTokens.dark,
      ]);
    });

    test('reaches both real themes, every one of them', () {
      // The failure this catches: a palette added to `chartExtensions` that
      // the theme never spreads. A chart reading it would throw at `of`, and
      // only at runtime — no test of the palette itself would notice.
      for (final extension in chartExtensions(Brightness.light)) {
        expect(AppTheme.light.extensions[extension.type], extension);
      }
      for (final extension in chartExtensions(Brightness.dark)) {
        expect(AppTheme.dark.extensions[extension.type], extension);
      }
    });

    test('is the only source of the chart palettes the themes carry', () {
      // Both known palette types arrive through the spread rather than being
      // named in `AppTheme`, which is the whole point of the seam.
      final types = chartExtensions(Brightness.light)
          .map((e) => e.type)
          .toSet();
      expect(types, contains(ChartPalette));
      expect(types, contains(AllocationPalette));
      expect(types, contains(PayoffPalette));
    });
  });
}
