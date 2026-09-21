import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/payoff_palette.dart';
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

/// The payoff curve's extra roles, measured the same way.
///
/// They live here rather than beside `PayoffPalette` so this file stays the
/// only one in `app/lib/` that names a `Color` — the invariant `ChartTokens`
/// documents above, which a second token file would quietly break.
///
/// Read from the design's own SVG template rather than from the rendered DOM:
/// `.design-refs/Catalog_RiskPayoffChart.dc.html` sets these as literal
/// `stroke`/`fill` attributes, so they are exact rather than sampled.
/// `specs/frontend/0005` §4 carries the full table.
///
/// Three roles are genuinely new. The two **region tints are derived**, not
/// transcribed: they are `ChartTokens`' own gain and loss marks at the alpha
/// the artboard washes them with, so a change to `barLoss` moves the wash
/// with it. Written out as literals they agreed with their source only until
/// somebody edited one.
abstract final class PayoffTokens {
  /// The alpha the `L1 · Light · 1024` artboard shades a region at.
  static const double lightWash = 0.07;

  /// The alpha the `D1 · Dark · 1024` artboard shades a region at — deeper,
  /// because the same 7 % is invisible over `#15161C`.
  static const double darkWash = 0.10;

  /// Light mode, as the `L1 · Light · 1024` artboard draws it.
  static final PayoffPalette light = PayoffPalette(
    breakEven: const Color(0xFFC07A10),
    zeroBaseline: const Color(0xFFB8BCC6),
    axisLabel: const Color(0xFF9A9BA4),
    lossRegion: ChartTokens.light.barLoss.withValues(alpha: lightWash),
    gainRegion: ChartTokens.light.barGain.withValues(alpha: lightWash),
  );

  /// Dark mode, as the `D1 · Dark · 1024` artboard draws it.
  static final PayoffPalette dark = PayoffPalette(
    breakEven: const Color(0xFFFFBF5C),
    zeroBaseline: const Color(0xFF3A3B44),
    axisLabel: const Color(0xFF7F828C),
    lossRegion: ChartTokens.dark.barLoss.withValues(alpha: darkWash),
    gainRegion: ChartTokens.dark.barGain.withValues(alpha: darkWash),
  );

  /// The palette for [brightness].
  static PayoffPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// Every chart `ThemeExtension` the app carries, for [brightness].
///
/// `AppTheme` spreads this rather than naming each palette, so a chart that
/// needs a palette of its own adds it **here** — beside the colours it is
/// made of — and `app/lib/theme/app_theme.dart` never grows again. GGU-55
/// added `ChartTokens` to that list and GGU-63 added `PayoffTokens`; a third
/// would have made it the `if/elif` chain ADR-L D-3 exists to prevent
/// (`specs/frontend/0005` OD-9).
List<ThemeExtension<Object?>> chartExtensions(Brightness brightness) =>
    <ThemeExtension<Object?>>[
      ChartTokens.forBrightness(brightness),
      PayoffTokens.forBrightness(brightness),
    ];
