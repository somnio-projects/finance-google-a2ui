import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// The app's Material 3 themes.
///
/// Both themes are derived from one seed colour, so light and dark stay in
/// step and every contrast pair is one Material 3 guarantees rather than one
/// somebody checked by eye once
/// (`.claude/rules/flutter/ui-theming.md`, WCAG 4.5:1).
///
/// Colours are read from `Theme.of(context).colorScheme` at the point of use;
/// a widget in this app never names a `Color` literal.
abstract final class AppTheme {
  /// The seed every scheme is generated from.
  static const Color seed = Color(0xFF1B6C4F);

  /// The light theme.
  static ThemeData get light => _build(Brightness.light);

  /// The dark theme.
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      extensions: <ThemeExtension<Object?>>[
        AppSpacing.standard,
        // Chart palettes are not derived from the seed: gain, loss and
        // "a total" are semantic roles Material 3 has no slot for, and the
        // values are the design's measured ones. Spread rather than listed,
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
