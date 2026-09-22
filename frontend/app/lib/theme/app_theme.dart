import 'package:finance_app/charts/chart_extensions.dart';
import 'package:finance_app/theme/activity_tokens.dart';
import 'package:finance_app/theme/app_colors.dart';
import 'package:finance_app/theme/app_spacing.dart';
import 'package:finance_app/theme/assistant_palettes.dart';
import 'package:finance_app/theme/holdings_tokens.dart';
import 'package:finance_app/theme/home_palettes.dart';
import 'package:finance_app/theme/login_palettes.dart';
import 'package:flutter/material.dart';

/// The app's Material 3 themes.
///
/// Both schemes are the design's **measured** surfaces (`AppColors`), not a
/// generated ramp. They used to be `ColorScheme.fromSeed` off one invented
/// green seed, which put a faintly green page behind charts whose own palette
/// had been measured from the design — the two halves of one screen obtained
/// two different ways. Contrast is therefore the designer's decision, and
/// `app_theme_test.dart` asserts the pairs Material used to guarantee
/// (`.claude/rules/flutter/ui-theming.md`, WCAG 4.5:1).
///
/// Colours are read from `Theme.of(context).colorScheme` at the point of use;
/// a widget in this app never names a `Color` literal.
abstract final class AppTheme {
  /// The light theme.
  static ThemeData get light => _build(Brightness.light);

  /// The dark theme.
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = AppColors.of(brightness);
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      // The page behind every surface. `ColorScheme.surface` is the card, so
      // without this the two are the same colour and the design's cards stop
      // reading as cards.
      scaffoldBackgroundColor: colorScheme.surfaceContainer,
      extensions: <ThemeExtension<Object?>>[
        AppSpacing.standard,
        // The shell's measured colours (spec 0026 §2) — not a chart palette,
        // so it sits beside the spacing rather than inside `chartExtensions`.
        homeTokensFor(brightness),
        loginTokensFor(brightness),
        holdingsTokensFor(brightness),
        activityTokensFor(brightness),
        assistantTokensFor(brightness),
        // Chart palettes stay separate: gain, loss and "a total" are semantic
        // roles Material 3 has no slot for, and they are measured the same way
        // the scheme above now is. Spread rather than listed,
        // so a new chart palette is an edit to `chart_tokens.dart` and never
        // to this file (ADR-L D-3, `specs/frontend/0005` OD-9).
        ...chartExtensions(brightness),
      ],
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
    );
  }
}
