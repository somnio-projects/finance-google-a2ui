import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'finance_tokens.dart';

/// Builds the app's light and dark themes.
///
/// Uses explicit [ColorScheme.light]/[ColorScheme.dark] instances rather than
/// [ColorScheme.fromSeed]: `fromSeed` derives a full Material tonal palette
/// algorithmically, which produces colours the design was never checked
/// against. Only the roles the app actually paints — primary/onPrimary,
/// surface/onSurface — are pinned; everything else keeps Flutter's baseline
/// Material defaults, which is a deliberate limit, not an oversight (see
/// [FinanceTokens] for the gain/loss/neutral colours feature widgets read
/// directly).
abstract final class AppTheme {
  static ThemeData light([FinanceTokens tokens = FinanceTokens.light]) =>
      _build(_lightScheme, tokens);

  static ThemeData dark([FinanceTokens tokens = FinanceTokens.dark]) =>
      _build(_darkScheme, tokens);

  static const ColorScheme _lightScheme = ColorScheme.light(
    primary: Color(0xFF4F5DFF),
    onPrimary: Colors.white,
    surface: Color(0xFFFDFBFF),
    onSurface: Color(0xFF1A1B20),
  );

  // Primary is a lighter tint than the light scheme's: a colour bright
  // enough for onSurface-level contrast on a dark background needs its own
  // (dark) onPrimary, rather than reusing the light scheme's white-on-#4F5DFF
  // pairing.
  static const ColorScheme _darkScheme = ColorScheme.dark(
    primary: Color(0xFF7A83FF),
    onPrimary: Color(0xFF101017),
    surface: Color(0xFF101017),
    onSurface: Color(0xFFE5E1E9),
  );

  static ThemeData _build(ColorScheme scheme, FinanceTokens tokens) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      extensions: <ThemeExtension<Object?>>[tokens],
    );
  }

  /// The Android status/navigation bar styling for [scheme], so the
  /// edge-to-edge system bars read as part of the app rather than a default
  /// black strip.
  ///
  /// `Colors.transparent` is not a themed colour — it means "no fill, defer
  /// to whatever is drawn beneath" — so it stays a plain constant rather than
  /// a token, but it lives here rather than at the call site to keep every
  /// system-chrome colour decision in one place.
  static SystemUiOverlayStyle systemOverlayStyle(ColorScheme scheme) {
    final Brightness iconBrightness = scheme.brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: iconBrightness,
      systemNavigationBarColor: scheme.surface,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: iconBrightness,
    );
  }
}
