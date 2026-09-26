import 'package:flutter/material.dart';

/// The colours that carry a **claim** rather than a surface.
///
/// Split out of `ScenarioComparisonTokens` when the redesign added the tick,
/// the direction hint and the recommendation tag: the card's other tokens say
/// *where a thing is drawn* (a row rule, a header hairline, an eyebrow), and
/// these eleven say *which column the backend picked and why*. Two different
/// questions, and together they were over the 150-line budget.
///
/// Every value was read out of the designer's `Catalog - Scenario Comparison`
/// page with `getComputedStyle` on the rendered DOM, in both the
/// `L1 · Light · 1024` and `D1 · Dark · 1024` artboards.
///
/// **The distinction the palette itself makes**, and the component's largest
/// visual error before it was measured: green means *a gain* and marks the
/// cell that won its row; lavender means *the thing to look at* and marks the
/// recommended column. Drawing the recommendation in green conflated two
/// claims the design keeps apart — and the tint is never "good", because it
/// can sit behind a figure that is itself a loss.
@immutable
class ScenarioVerdictTokens {
  /// Creates a verdict palette. Every colour is required.
  const ScenarioVerdictTokens({
    required this.winnerSurface,
    required this.winnerBorder,
    required this.winnerAccent,
    required this.winnerTickGlyph,
    required this.directionHint,
    required this.recommendedSurface,
    required this.recommendedBorder,
    required this.recommendedText,
    required this.recommendedTagSurface,
    required this.recommendedTagBorder,
  });

  /// Light mode, as the `L1 · Light · 1024` artboard draws it.
  static const ScenarioVerdictTokens light = ScenarioVerdictTokens(
    winnerSurface: Color(0xFFE3F3EC),
    winnerBorder: Color(0xFFBFE4D1),
    winnerAccent: Color(0xFF12805C),
    winnerTickGlyph: Color(0xFFFFFFFF),
    directionHint: Color(0xFFA0A3AC),
    recommendedSurface: Color(0xFFEEF0FF),
    recommendedBorder: Color(0xFFCDD2FF),
    recommendedText: Color(0xFF3A2F70),
    recommendedTagSurface: Color(0xFFE2E0FB),
    recommendedTagBorder: Color(0xFFC9C6F5),
  );

  /// Dark mode, as the `D1 · Dark · 1024` artboard draws it.
  static const ScenarioVerdictTokens dark = ScenarioVerdictTokens(
    winnerSurface: Color(0xFF12291F),
    winnerBorder: Color(0xFF1F4536),
    winnerAccent: Color(0xFF4ADE9E),
    winnerTickGlyph: Color(0xFF06301F),
    directionHint: Color(0xFF75777F),
    recommendedSurface: Color(0xFF20223A),
    recommendedBorder: Color(0xFF3A3B6E),
    recommendedText: Color(0xFFC9C6FF),
    recommendedTagSurface: Color(0xFF2A2748),
    recommendedTagBorder: Color(0xFF3F3A68),
  );

  /// The tint behind the cell that wins its row.
  ///
  /// A **surface**, not a semantic green: it says *"best in this row"* and
  /// never *"good"*. Which direction a row is read in is stated beside it —
  /// the backend writes `higher is better` or `lower is better` per row (N-9).
  final Color winnerSurface;

  /// The 1 px border around that cell.
  ///
  /// The design draws **both** a tint and a border; a tint alone was this
  /// component's first guess and it read as a wash rather than a marked cell.
  final Color winnerBorder;

  /// The winning figure's colour, and the tick's fill behind its glyph.
  ///
  /// One value for both, because the design uses one: `gain` in the shared
  /// palette. It is the green of a gain, which is why it can colour a figure
  /// — and why [winnerSurface] cannot.
  final Color winnerAccent;

  /// The `✓` inside the tick, drawn on [winnerAccent].
  final Color winnerTickGlyph;

  /// The `higher is better` line under a row's name, a step quieter than it.
  final Color directionHint;

  /// The recommended column header's fill — lavender, the `hlBg` the order
  /// ticket uses to highlight a leg.
  final Color recommendedSurface;

  /// That header's 1 px border.
  final Color recommendedBorder;

  /// The recommendation tag's text, and its star.
  final Color recommendedText;

  /// The tag's own fill, a step from the header it sits on.
  final Color recommendedTagSurface;

  /// The tag's 1 px border.
  final Color recommendedTagBorder;
}
