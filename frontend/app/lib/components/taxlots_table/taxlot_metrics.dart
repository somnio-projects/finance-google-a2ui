import 'package:flutter/widgets.dart';

/// Every distance, radius and type size the tax-lot table draws with,
/// **measured from the design** rather than chosen.
///
/// They live as named constants for the reason ADR-L D-15 gives: a
/// cross-platform raster cannot resolve a 1 px radius change, so the values a
/// golden would miss are asserted from the widget tree instead — by
/// `taxlot_row_tile_test.dart` and `taxlot_parts_test.dart`. A widget that
/// reached for a literal `10` would put the design value somewhere no test
/// is looking.
abstract final class TaxLotMetrics {
  /// The card: `border-radius: 16px`, `padding: 16px 18px 14px`.
  static const double cardRadius = 16;

  /// The card's rounding, ready to hand to a `BoxDecoration`.
  ///
  /// The five radii below are *always* wanted as a `BorderRadius`, so each
  /// is offered as one. It keeps `BorderRadius.circular(...)` out of six
  /// call sites and off both sides of the assertions that pin them.
  static BorderRadius get cardBorderRadius => BorderRadius.circular(cardRadius);

  /// A row's rounding.
  static BorderRadius get rowBorderRadius => BorderRadius.circular(rowRadius);

  /// A row's rounding measured *inside* its 1 px hairline, so the term rail
  /// follows the corner instead of squaring it off.
  static BorderRadius get rowInnerBorderRadius =>
      BorderRadius.circular(rowRadius - 1);

  /// The footer bar's rounding.
  static BorderRadius get footerBorderRadius =>
      BorderRadius.circular(footerRadius);

  /// Any pill's rounding.
  static BorderRadius get chipBorderRadius => BorderRadius.circular(chipRadius);

  /// The tick box's rounding.
  static BorderRadius get checkBoxBorderRadius =>
      BorderRadius.circular(checkBoxRadius);

  /// The card's padding. The foot is tighter than the head because the
  /// footer bar already carries 12 px of its own top margin.
  static const EdgeInsets cardPadding = EdgeInsets.fromLTRB(18, 16, 18, 14);

  /// The gap under the card's header line, and above the footer bar.
  static const double headerGap = 12;

  /// A row: `border-radius: 10px`, `height: 48px`, `gap: 7px`.
  static const double rowRadius = 10;

  /// The row's fixed height.
  ///
  /// Fixed, not intrinsic: the design's rows are a constant 48 px and a row
  /// that grew with its text would drift from the artboard on the first
  /// long date. Every cell is one line.
  static const double rowHeight = 48;

  /// The vertical gap between two rows.
  static const double rowGap = 7;

  /// The rail down the left of a row that marks its term.
  static const double rowAccentWidth = 3;

  /// The row's inner padding, measured from *inside* the 1 px hairline and
  /// the 3 px rail: the design's `padding: 9px 10px` on a `1px 1px 1px 3px`
  /// border puts text 13 px from the left edge and 11 px from the right.
  static const EdgeInsets rowPadding = EdgeInsets.fromLTRB(9, 0, 10, 0);

  /// The column-header line: `padding: 0 10px 6px`.
  static const EdgeInsets columnHeaderPadding = EdgeInsets.fromLTRB(
    10,
    0,
    10,
    6,
  );

  /// The gap between two columns, in a row and in the header.
  static const double columnGap = 8;

  /// The fixed first column, which holds the 16 px box.
  static const double checkColumnWidth = 26;

  /// The tick box: `16 × 16`, `border-radius: 4px`, `border-width: 1.5px`.
  static const double checkBoxSize = 16;

  /// That box's corner radius.
  static const double checkBoxRadius = 4;

  /// That box's hairline.
  static const double checkBoxBorderWidth = 1.5;

  /// The design's `grid-template-columns` after the first, fixed column:
  /// `1.05fr 0.95fr 0.95fr 1fr 1.02fr`, as integer flex weights.
  ///
  /// The design has a sixth, `0.55fr` **Shares** column that this build does
  /// not draw — the contract's only per-lot quantity is the raw `units`
  /// string, which N-4 forbids putting on screen (spec `frontend/0003`
  /// OD-2). The remaining weights are the design's, untouched.
  static const List<int> columnFlex = <int>[105, 95, 95, 100, 102];

  /// The footer bar: `border-radius: 12px`, `padding: 11px 14px`, `gap: 12px`.
  static const double footerRadius = 12;

  /// The footer bar's padding.
  static const EdgeInsets footerPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 11,
  );

  /// The gap between the footer's caption, total and split pills.
  static const double footerGap = 12;

  /// A pill inside a row: `border-radius: 20px`, `padding: 2px 7px`.
  static const EdgeInsets rowChipPadding = EdgeInsets.symmetric(
    horizontal: 7,
    vertical: 2,
  );

  /// A pill in the legend: `padding: 2px 8px`, plus a hairline.
  static const EdgeInsets legendChipPadding = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 2,
  );

  /// A pill in the footer: `padding: 3px 9px`.
  static const EdgeInsets footerChipPadding = EdgeInsets.symmetric(
    horizontal: 9,
    vertical: 3,
  );

  /// Every pill's corner radius.
  static const double chipRadius = 20;

  /// The gap between two legend pills, and between a row's pill and the
  /// holding-period text beside it.
  static const double chipGap = 8;

  /// The dashed square the empty state draws: `40 × 40`, radius 10.
  static const double placeholderSize = 40;

  /// That square's corner radius.
  static const double placeholderRadius = 10;

  /// The empty state's `padding: 22px 0` and its `gap: 10px`.
  static const double placeholderPadding = 22;

  /// The gap between the dashed square and the sentence under it.
  static const double placeholderGap = 10;
}
