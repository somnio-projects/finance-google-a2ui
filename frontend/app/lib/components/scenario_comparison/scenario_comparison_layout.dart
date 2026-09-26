import 'package:flutter/material.dart';

/// The card's measured geometry.
///
/// Every number is read from the designer's rendered DOM, not chosen: the
/// card's chrome, the grid's track ratios and gap, and the padding of each
/// kind of cell. `specs/frontend/0004` §3 carries the table.
abstract final class ScenarioComparisonLayout {
  /// Every hairline on this card: the card's own, a column header's, a row
  /// rule.
  ///
  /// **It has to be added to a padding, and that is not a detail.** The
  /// design is CSS `box-sizing: border-box`, where a 1 px border sits
  /// *inside* the declared width and the content box shrinks by it. Flutter
  /// inverts that: `DecoratedBox` and `CustomPaint` paint over the child
  /// and reserve no space, so the same padding leaves the content box 2 px
  /// wider than the design's. Each use site therefore pads by its measured
  /// value **plus** this, on the edges that carry a line.
  ///
  /// Not theoretical: the grid tracks came out 209.30 / 155.03 against the
  /// designer's 208.48 / 154.44 until this was added, and
  /// `scenario_comparison_table_test.dart` is what said so.
  static const double hairline = 1;

  /// The card's corner radius.
  static const double cardRadius = 16;

  /// The card's padding — note the bottom is 1 px shallower than the top.
  static const EdgeInsets cardPadding = EdgeInsets.fromLTRB(18, 16, 18, 15);

  /// The gap between two grid tracks (`gap: 8px`).
  static const double columnGap = 8;

  /// A column header's padding.
  static const EdgeInsets headerCellPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 8,
  );

  /// A column header's top corners; its bottom edge is open onto the table.
  static const double headerCellRadius = 10;

  /// The `Metric` caption's padding — bottom-aligned against the headers.
  static const EdgeInsets metricHeaderPadding = EdgeInsets.fromLTRB(2, 0, 2, 4);

  /// The padding a metric row adds inside its hairline.
  static const EdgeInsets rowPadding = EdgeInsets.symmetric(vertical: 2);

  /// A metric name's padding in the left-hand track.
  static const EdgeInsets metricCellPadding = EdgeInsets.symmetric(
    horizontal: 2,
    vertical: 9,
  );

  /// A figure's padding in a scenario track.
  static const EdgeInsets valueCellPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 9,
  );

  /// A figure cell's corner radius.
  ///
  /// Nothing fills that shape in this build: in the design it is the
  /// rounding of the green "best on that row" chip, which is the
  /// recommendation affordance the card omits (`specs/frontend/0004` OD-3).
  /// It is kept because the cell's padding is measured *with* it, and a
  /// later state — a tap highlight — will want the same silhouette.
  static const double valueCellRadius = 8;

  /// The flex of a scenario track. The tracks are `1fr` each.
  static const int scenarioFlex = 100;

  /// The flex of the metric-name track, against [scenarioFlex].
  ///
  /// The design narrows it as scenarios are added — `1.35fr` at two columns
  /// and `1.2fr` at three — so the figures keep their width. Both values are
  /// measured; there is no third artboard, and a straight line through two
  /// points would be fitting rather than reading. Anything the contract
  /// cannot currently produce falls back to the three-column ratio, which is
  /// the tightest the designer has actually drawn.
  ///
  /// Only 2 and 3 are reachable: the options model requires at least two
  /// methods and caps at `MAX_SCENARIOS = len(LotMethod)`, which is three
  /// (spec `backend/0017` §3).
  static int metricFlex(int scenarioCount) =>
      const <int, int>{2: 135, 3: 120}[scenarioCount] ?? 120;
}

/// The type the card draws in, at the design's measured sizes.
///
/// **Deliberate divergence, and the same one `ChartText` records.** The
/// design sets the eyebrow and every figure in Roboto Mono; this app bundles
/// no font asset. A designer reaches for a mono face here to line digits up
/// in a column, and `tabularFigures` buys exactly that from the bundled font
/// without a 60 kB download. `specs/frontend/0004` OD-5 keeps it open with
/// design.
