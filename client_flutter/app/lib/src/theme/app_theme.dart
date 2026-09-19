import 'package:flutter/material.dart';

import 'finance_tokens.dart';

/// Builds the app's light and dark themes from [FinanceTokens].
abstract final class AppTheme {
  static ThemeData light([FinanceTokens tokens = FinanceTokens.light]) =>
      _build(tokens, Brightness.light);

  static ThemeData dark([FinanceTokens tokens = FinanceTokens.dark]) =>
      _build(tokens, Brightness.dark);

  static ThemeData _build(FinanceTokens tokens, Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: tokens.brandAccent,
        brightness: brightness,
      ),
      useMaterial3: true,
      extensions: <ThemeExtension<Object?>>[tokens],
    );
  }
}
