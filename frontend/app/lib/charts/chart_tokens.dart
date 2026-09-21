import 'package:finance_app/charts/chart_palette.dart';
import 'package:flutter/material.dart';

/// The chart palette in each brightness, **measured from the design**.
///
/// Every value below was read out of the designer's catalog page by
/// inspecting the rendered DOM (`getComputedStyle`) rather than taken from a
/// hand-written token list — two of the five values circulated informally
/// were wrong: the dark surface is `#15161C`, not `#14151A`, and the dark
/// neutral bar is `#6F7280`, not `#4B4D57`. `specs/frontend/0002` records the
/// full table and how it was obtained.
///
/// This is the only file in `app/lib/` that names a `Color`, which is the same
/// arrangement `AppTheme` has for the seed: literals live in the theme layer,
/// and a widget reads [ChartPalette.of].
abstract final class ChartTokens {
  /// Light mode, as the `L1 · Light · 1024` artboard draws it.
  static const ChartPalette light = ChartPalette(
    surface: Color(0xFFFDFBFF),
    border: Color(0xFFEAE7F0),
    title: Color(0xFF1A1B20),
    barNeutral: Color(0xFF8A8D96),
    barGain: Color(0xFF12805C),
    barLoss: Color(0xFFC0362C),
    barTotal: Color(0xFF4F5DFF),
    connector: Color(0xFFC4C6D0),
    rule: Color(0xFFF0EEF5),
    mutedLabel: Color(0xFF5F6169),
  );

  /// Dark mode, as the `D1 · Dark · 1024` artboard draws it.
  ///
  /// The geometry is pixel-identical between the two artboards — only the
  /// palette changes — which is why one layout serves both.
  static const ChartPalette dark = ChartPalette(
    surface: Color(0xFF15161C),
    border: Color(0xFF24252D),
    title: Color(0xFFE5E1E9),
    barNeutral: Color(0xFF6F7280),
    barGain: Color(0xFF4ADE9E),
    barLoss: Color(0xFFFF6B5E),
    barTotal: Color(0xFF7A83FF),
    connector: Color(0xFF3A3B44),
    rule: Color(0xFF24252D),
    mutedLabel: Color(0xFFA4A6B0),
  );

  /// The palette for [brightness].
  static ChartPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
