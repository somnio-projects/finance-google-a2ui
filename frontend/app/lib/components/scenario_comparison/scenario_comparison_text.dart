import 'package:flutter/material.dart';

/// The card's type scale, measured from the design's rendered DOM.
///
/// Its own file since the redesign added the direction hint and the
/// recommended tag and pushed `scenario_comparison_layout` past the budget.
/// Layout is *where things sit*; this is *what they look like*, and the two
/// were only ever together because both were short.
///
/// There is no style for the winning cell's `✓`. The design sets it as
/// `font:700 9px` text, and a slot for it was written here and deleted: the
/// glyph is not in Roboto, so it rendered as a filled blob, and the tick is
/// drawn as `Icons.check` inside a disc instead. A style nothing reaches is
/// a coverage failure before it is anything else.
abstract final class ScenarioComparisonText {
  /// An eyebrow: a subject caption, or a column's secondary line.
  ///
  /// The design also uppercases its eyebrows with a CSS `text-transform`.
  /// This style does **not**, and callers must not: the strings in those
  /// slots are server-written labels, and `toUpperCase()` on one is the
  /// client altering a value the backend formatted (N-1, N-9).
  static TextStyle caption(Color color) => TextStyle(
    color: color,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );

  /// The `Metric` caption over the left-hand track.
  ///
  /// **Not [caption], though it looks like one.** Both artboards of both
  /// design exports draw it at weight **500 with normal tracking**, while an
  /// eyebrow is 600 at `0.08em`. Reusing [caption] here was a real fidelity
  /// miss, caught by re-measuring against the newer design export.
  static TextStyle metricHeading(Color color) =>
      TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500);

  /// A column header's first line: the lot-selection method.
  static TextStyle columnTitle(Color color) =>
      TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w500);

  /// A column header's second line: the backend's descriptive label.
  static TextStyle columnLabel(Color color) =>
      TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w400);

  /// A metric's name in the left-hand track.
  static TextStyle metricLabel(Color color) =>
      TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w400);

  /// `higher is better ▲` under a metric's name.
  ///
  /// The arrow is **in the string**, not drawn here: the backend writes
  /// `direction_label` and the client renders it verbatim (N-9).
  static TextStyle directionHint(Color color) =>
      TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w400);

  /// The `★ Recommended` tag on a column header.
  ///
  /// Tracked like an eyebrow but **not uppercased**, for the reason
  /// [caption] states: the label is a server-written string and
  /// `toUpperCase()` on one is the client altering a formatted value. The
  /// design's CSS does it with `text-transform`; the contract does not.
  static TextStyle recommendedTag(Color color) => TextStyle(
    color: color,
    fontSize: 9,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.36,
  );

  /// A figure in a scenario track.
  static TextStyle value(Color color) => TextStyle(
    color: color,
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );
}
