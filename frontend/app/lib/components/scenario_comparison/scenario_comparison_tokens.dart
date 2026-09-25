import 'package:flutter/material.dart';

/// The four colours this card needs that `ChartPalette` has no slot for,
/// **measured from the design** rather than taken from a token list.
///
/// Every value below was read out of the designer's
/// `Catalog - Scenario Comparison` page with `getComputedStyle` on the
/// rendered DOM, in both the `L1 · Light · 1024` and `D1 · Dark · 1024`
/// artboards. `specs/frontend/0004` carries the full table and how it was
/// obtained; `scenario_comparison_tokens_test.dart` pins all eight values so
/// a future edit has to disagree with a test rather than with a memory.
///
/// **Why a second colour file exists.** `chart_tokens.dart` used to say it
/// was the only file in `app/lib/` naming a `Color`, and that was true while
/// one component had been built. Three of this card's colours are simply not
/// chart roles — a table's row rule, a column header's hairline, a caption —
/// and `ChartPalette` has no field for them. Adding four would edit
/// `chart_palette.dart` and `chart_tokens.dart`, and *adding a component
/// edits no existing file* (ADR-L D-3). So the card brings its own, and the
/// stale sentence is raised in `specs/frontend/0004` OD-6 rather than fixed
/// quietly here.
///
/// The card's surface, hairline and primary text are **not** duplicated: they
/// coincide with `ChartPalette.surface`, `.border` and `.title` because both
/// components sit on the same artboard, so the card reads those from the
/// theme.
@immutable
class ScenarioComparisonTokens {
  /// Creates a token set. Every colour is required — a table drawn in a
  /// fallback colour looks plausible and is wrong.
  const ScenarioComparisonTokens({
    required this.caption,
    required this.metricLabel,
    required this.rowRule,
    required this.headerBorder,
  });

  /// Light mode, as the `L1 · Light · 1024` artboard draws it.
  static const ScenarioComparisonTokens light = ScenarioComparisonTokens(
    caption: Color(0xFF8A8D96),
    metricLabel: Color(0xFF44464E),
    rowRule: Color(0xFFF0EDF5),
    headerBorder: Color(0xFFEAE7F0),
  );

  /// Dark mode, as the `D1 · Dark · 1024` artboard draws it.
  ///
  /// [caption] is the one value the two artboards share: the design keeps
  /// the same neutral for an eyebrow in both themes.
  static const ScenarioComparisonTokens dark = ScenarioComparisonTokens(
    caption: Color(0xFF8A8D96),
    metricLabel: Color(0xFFC9CBD4),
    rowRule: Color(0xFF202128),
    headerBorder: Color(0xFF2A2B33),
  );

  /// The token set for [brightness].
  static ScenarioComparisonTokens forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Reads the token set matching [context]'s theme brightness.
  static ScenarioComparisonTokens of(BuildContext context) =>
      forBrightness(Theme.of(context).brightness);

  /// An eyebrow: the subject captions and a column's secondary line.
  ///
  /// The same neutral the catalog index uses for its token legend.
  final Color caption;

  /// A metric's name in the left-hand column.
  ///
  /// Cross-checked against the catalog index's shared legend, which draws
  /// `Short-term` / `Long-term` in exactly this colour.
  final Color metricLabel;

  /// The hairline above each metric row.
  ///
  /// Deliberately **not** `ChartPalette.rule`: the design draws a table's
  /// row rule one step lighter than a chart's axis rule (`#F0EDF5` against
  /// `#F0EEF5`) and two steps lighter in dark mode (`#202128` against
  /// `#24252D`).
  final Color rowRule;

  /// The hairline around a column header's top and sides.
  ///
  /// Equal to `ChartPalette.border` in light mode and a step lighter than it
  /// in dark (`#2A2B33` against `#24252D`), which is why it is its own token
  /// rather than a reuse that happens to be right half the time.
  final Color headerBorder;
}
