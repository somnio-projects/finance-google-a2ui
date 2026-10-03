import 'package:flutter/widgets.dart';

/// Every distance and radius the tax-lot **table** draws with, measured from
/// the UI Kit's desktop artboards (`specs/frontend/assets/0027-taxlot-uikit/`).
///
/// They live as named constants for the reason ADR-L D-15 gives: a
/// cross-platform raster cannot resolve a 1 px change, so the values a golden
/// would miss are asserted from the widget tree instead. A widget that reached
/// for a literal `41` would put a design value somewhere no test is looking.
///
/// The phone form's numbers are in `TaxLotMobileMetrics`; the two are separate
/// files because they are separate measurements, and one table of forty
/// constants is not a table anybody reads.
abstract final class TaxLotMetrics {
  /// The card: 640 × 346 with a 16 px radius, on a 600 px content column.
  static const double cardRadius = 16;

  /// The card's rounding, ready for a `BoxDecoration`.
  static BorderRadius get cardBorderRadius => BorderRadius.circular(cardRadius);

  /// The card's padding: `20` at the sides, `24` above the header. The foot
  /// is `0` because the footer carries its own inset — the kit's rule runs
  /// the full content width and the line under it is the card's last 56 px.
  static const EdgeInsets cardPadding = EdgeInsets.fromLTRB(20, 24, 20, 0);

  /// The gap under the header line, above the column captions.
  static const double headerGap = 18;

  /// The gap under the column captions, above the first row.
  static const double captionGap = 12;

  /// Below this **content** width the card stacks its lots as phone cards.
  ///
  /// A property of the card, not of the screen: it is laid out by whatever
  /// column the Assistant, the catalog or Home puts it in, so `LayoutBuilder`
  /// asks the constraint rather than the media query (spec `frontend/0027`
  /// OD-7). It is measured *inside* [cardPadding], where the `LayoutBuilder`
  /// sits, because that is the width the columns actually get: 420 sits
  /// between the kit's two artboards, which give the table 600 of content and
  /// the phone form 328.
  static const double stackBelow = 420;

  /// A row's height. Fixed, not intrinsic: the kit's rows are a constant
  /// 41 px and a row that grew with its text would drift from the artboard on
  /// the first long date. Every cell is one line.
  static const double rowHeight = 41;

  /// The vertical gap between two rows.
  static const double rowGap = 8;

  /// The rail that marks a row's term, flush with the content's left edge.
  static const double railWidth = 4;

  /// The gap after the rail, and again after the tick box.
  static const double railGap = 9;

  /// The fully-sold mark's diameter — the kit's 16 px box, now round and
  /// drawn only for a lot the sale consumes whole (GGU-148).
  static const double soldMarkSize = 16;

  /// The 1.5 px hairline the empty state's dashed box is drawn with.
  static const double checkBoxBorderWidth = 1.5;

  /// The six columns' widths, as integer flex weights.
  ///
  /// Derived from the artboard's own ink: the right-aligned columns end at
  /// 1442, 1530, 1626 and 1716 on a content column running 1300 → 1863, which
  /// fixes every boundary once the 8 px gap is known. In order: acquired,
  /// shares, cost basis, market value, gain/loss, holding period.
  static const List<int> columnFlex = <int>[80, 54, 80, 88, 82, 139];

  /// The gap between two columns, in a row and in the caption line.
  static const double columnGap = 8;

  /// How each column's content sits in its cell.
  ///
  /// The date reads left, the four figures right, and the holding period is
  /// **centred** — which is what the artboard does: its caption's ink centres
  /// in that cell to within 2 px. See OD-2 for what is missing from it.
  static const List<TextAlign> columnAlign = <TextAlign>[
    TextAlign.left,
    TextAlign.right,
    TextAlign.right,
    TextAlign.right,
    TextAlign.right,
    TextAlign.center,
  ];

  /// A term pill: radius 8.5, `padding: 2px 9px`, 17 px tall.
  static const double chipRadius = 8.5;

  /// Any pill's rounding.
  static BorderRadius get chipBorderRadius => BorderRadius.circular(chipRadius);

  /// A pill's inset inside a row or the legend.
  static const EdgeInsets chipPadding = EdgeInsets.symmetric(
    horizontal: 9,
    vertical: 2,
  );

  /// A pill in the footer, which the kit sets a shade roomier.
  static const EdgeInsets footerChipPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 3,
  );

  /// The gap between the two legend pills, and between the footer's.
  static const double chipGap = 8;

  /// The gap between the last row and the card's one rule.
  static const double dividerGap = 12;

  /// That rule.
  static const double dividerThickness = 1;

  /// The footer band under the rule: `16` above the line of text, `17` below.
  static const EdgeInsets footerPadding = EdgeInsets.fromLTRB(0, 16, 0, 17);

  /// The gap between the footer's caption, its total and the split pills.
  static const double footerGap = 12;

  /// The dashed square the empty state draws: 40 × 40, radius 10.
  ///
  /// Not in this frame — the kit draws no empty tax-lot card — so it keeps
  /// the geometry the earlier artboard gave it (spec `frontend/0003`).
  static const double placeholderSize = 40;

  /// That square's corner radius.
  static const double placeholderRadius = 10;

  /// The empty state's vertical padding.
  static const double placeholderPadding = 22;

  /// The gap between the dashed square and the sentence under it.
  static const double placeholderGap = 10;
}
