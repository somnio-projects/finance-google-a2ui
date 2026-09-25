import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/charts/payoff_palette.dart';
import 'package:flutter/material.dart';

// Split out of `chart_tokens.dart` when a third palette pushed that file past
// the 150-line budget. The budget is a gate; "one file names every Color" was
// a preference, and the rule this repository already wrote for the backend
// applies here too — the budget wins and the grouping is kept obvious by the
// name instead (ADR-L D-3).

/// The payoff curve's extra roles, measured the same way.
///
/// They live here rather than beside `PayoffPalette` because a colour literal
/// belongs in a `*_tokens.dart`. This comment used to say the file stayed the
/// only one in `app/lib/` naming a `Color`, which was already false as it was
/// written — this file is itself the second chart token file. The rule is now
/// `app/test/architecture/color_rules_test.dart` (spec frontend/0029 OD-4).
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
