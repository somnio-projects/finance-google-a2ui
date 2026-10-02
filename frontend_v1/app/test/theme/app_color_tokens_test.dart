import 'package:finance_app/theme/app_color_tokens.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(AppColors, () {
    test('the scheme is measured from the design, not a seeded ramp', () {
      // Literals, on purpose — the counterpart of the backend's
      // `test_component_names.py`. Every other assertion here reads both
      // halves from `AppColors` and so cannot notice the whole palette
      // drifting together; these five were read out of the designer's own
      // pages with `getComputedStyle`, and they are what the app must render.
      //
      // This replaces an assertion that the seed was `#1B6C4F`. That seed is
      // gone: Material derived every surface from it, which put a faintly
      // green page behind charts whose palette had been measured from the
      // design — one screen, two provenances.
      expect(AppTheme.light.scaffoldBackgroundColor, const Color(0xFFF7F6FB));
      expect(AppTheme.dark.scaffoldBackgroundColor, const Color(0xFF0B0C10));
      expect(AppTheme.light.colorScheme.surface, const Color(0xFFFDFBFF));
      expect(AppTheme.dark.colorScheme.surface, const Color(0xFF15161C));
      expect(AppTheme.light.colorScheme.primary, const Color(0xFF4F5DFF));
    });

    test('the page and the card are different colours', () {
      // The failure this catches: `scaffoldBackgroundColor` left at its
      // default equals `surface`, so every card dissolves into the page and
      // the design's card edges stop existing.
      for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
        expect(
          theme.scaffoldBackgroundColor,
          isNot(equals(theme.colorScheme.surface)),
        );
      }
    });

    test('AppColors answers per brightness', () {
      expect(AppColors.of(Brightness.light).brightness, Brightness.light);
      expect(AppColors.of(Brightness.dark).brightness, Brightness.dark);
    });
  });
}
