import 'package:flutter/material.dart';

/// The design's own surface and text colours, **measured, not generated**.
///
/// Every value here was read out of the designer's pages by inspecting the
/// rendered DOM (`getComputedStyle`), the same way `charts/chart_tokens.dart`
/// was obtained — and for the same reason. The app used to build both schemes
/// with `ColorScheme.fromSeed(Color(0xFF1B6C4F))`, so Material derived every
/// surface, card, divider and text colour algorithmically from one invented
/// green seed. That is a defensible way to build an app and the wrong way to
/// build *this* one: the page background came out faintly green where the
/// design is a cool near-white, and no amount of care downstream could fix it,
/// because nothing downstream named a colour at all.
///
/// The chart palettes were already measured, which is what made the gap
/// visible: the bars matched the design and the page behind them did not.
///
/// | role | light | dark |
/// |---|---|---|
/// | page background | `#F7F6FB` | `#0B0C10` |
/// | card / surface | `#FDFBFF` | `#15161C` |
/// | raised surface | `#F0EDF7` | `#24252D` |
/// | primary text | `#1A1B20` | `#E5E1E9` |
/// | secondary text | `#5F6169` | `#A4A6B0` |
/// | divider | `#E5E1E9` | `#2B2C34` |
/// | accent (indigo) | `#4F5DFF` | `#C9CBFF` |
abstract final class AppColors {
  /// The page behind every surface.
  static const Color backgroundLight = Color(0xFFF7F6FB);

  /// The page behind every surface, at night.
  static const Color backgroundDark = Color(0xFF0B0C10);

  /// A card, sheet or any surface that sits on the page.
  static const Color surfaceLight = Color(0xFFFDFBFF);

  /// A card, sheet or any surface that sits on the page, at night.
  static const Color surfaceDark = Color(0xFF15161C);

  /// A surface raised above another surface — a chip, a filled field.
  static const Color surfaceRaisedLight = Color(0xFFF0EDF7);

  /// A surface raised above another surface, at night.
  static const Color surfaceRaisedDark = Color(0xFF24252D);

  /// Body and heading text.
  static const Color onSurfaceLight = Color(0xFF1A1B20);

  /// Body and heading text, at night.
  static const Color onSurfaceDark = Color(0xFFE5E1E9);

  /// Labels, captions and anything deliberately quieter than body text.
  static const Color onSurfaceMutedLight = Color(0xFF5F6169);

  /// Labels and captions, at night.
  static const Color onSurfaceMutedDark = Color(0xFFA4A6B0);

  /// Hairlines between rows and around cards.
  static const Color outlineLight = Color(0xFFE5E1E9);

  /// Hairlines between rows and around cards, at night.
  static const Color outlineDark = Color(0xFF2B2C34);

  /// The accent the design uses for totals, selection and emphasis.
  static const Color accentLight = Color(0xFF4F5DFF);

  /// The accent, at night — lightened so it carries on a dark surface.
  static const Color accentDark = Color(0xFFC9CBFF);

  /// Text drawn on top of [accentLight].
  static const Color onAccentLight = Color(0xFFFFFFFF);

  /// Text drawn on top of [accentDark].
  static const Color onAccentDark = Color(0xFF3A2F70);

  /// The scheme for [brightness], built from the rows above.
  ///
  /// `ColorScheme` is written out rather than seeded, so what the app renders
  /// is what the design measured. The pairs are the design's own, so the
  /// contrast they carry is the designer's decision — `app_theme_test.dart`
  /// asserts the ones Material would otherwise have guaranteed.
  static ColorScheme of(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;

  static const ColorScheme _light = ColorScheme(
    brightness: Brightness.light,
    primary: accentLight,
    onPrimary: onAccentLight,
    secondary: accentLight,
    onSecondary: onAccentLight,
    error: Color(0xFFC0362C),
    onError: Color(0xFFFFFFFF),
    surface: surfaceLight,
    onSurface: onSurfaceLight,
    surfaceContainerLowest: surfaceLight,
    surfaceContainer: backgroundLight,
    surfaceContainerHigh: surfaceRaisedLight,
    onSurfaceVariant: onSurfaceMutedLight,
    outline: outlineLight,
    outlineVariant: outlineLight,
  );

  static const ColorScheme _dark = ColorScheme(
    brightness: Brightness.dark,
    primary: accentDark,
    onPrimary: onAccentDark,
    secondary: accentDark,
    onSecondary: onAccentDark,
    error: Color(0xFFFF6B5E),
    onError: Color(0xFF1A1B20),
    surface: surfaceDark,
    onSurface: onSurfaceDark,
    surfaceContainerLowest: surfaceDark,
    surfaceContainer: backgroundDark,
    surfaceContainerHigh: surfaceRaisedDark,
    onSurfaceVariant: onSurfaceMutedDark,
    outline: outlineDark,
    outlineVariant: outlineDark,
  );
}
