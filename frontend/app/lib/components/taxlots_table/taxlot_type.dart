import 'package:flutter/widgets.dart';

/// The type scale the tax-lot card draws with, **measured from the UI Kit**.
///
/// Sizes come from the raster's ink extents — the export outlines its text, so
/// there is no `font-size` to read — and each was divided by the face's own
/// cap or ascender ratio: a 12 px cap on the title is a 17 px face, a 12 px
/// `$`-to-baseline run on a money column is 13 px.
///
/// The *families* are not the design's. It sets Inter and Roboto Mono and this
/// app bundles no font; spec `frontend/0002` OD-4 settled that for the
/// waterfall — `tabularFigures` on the bundled face buys the digit alignment a
/// money column needs without a 60 kB download — and this card follows it
/// rather than reopening the question (`frontend/0003` OD-6).
///
/// Every role is a **function of its colour**, because that is how all of them
/// are used: the size and weight belong to the design, the colour belongs to
/// `TaxLotPalette` and differs per artboard. Returning the style already
/// tinted keeps `.copyWith(color: …)` out of a dozen call sites.
abstract final class TaxLotType {
  /// Figures line up column-wise without a monospaced family.
  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// The card's title — the kit's `NVDA · 4 lots` slot, 17 px semibold.
  static TextStyle title(Color color) => TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: color,
  );

  /// The line under it, from the payload's `subtitle` (OD-4).
  static TextStyle subtitle(Color color) =>
      TextStyle(fontSize: 11.5, height: 1.25, color: color);

  /// A column caption: 11 px regular.
  static TextStyle caption(Color color) =>
      TextStyle(fontSize: 11, height: 1.2, color: color);

  /// A row's acquisition date, and its share count.
  static TextStyle cell(Color color) => TextStyle(
    fontSize: 13,
    height: 1.2,
    fontFeatures: _tabular,
    color: color,
  );

  /// The market-value column, which the kit sets a weight heavier than the
  /// cost basis beside it.
  static TextStyle cellStrong(Color color) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
    fontFeatures: _tabular,
    color: color,
  );

  /// The gain/loss column: the same size, a medium weight, and the one colour
  /// in a row that comes from the payload's `trend`.
  static TextStyle cellAccent(Color color) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.2,
    fontFeatures: _tabular,
    color: color,
  );

  /// A term pill, in a row and in the legend alike — the kit draws one size.
  static TextStyle chip(Color color) => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: color,
  );

  /// The footer's caption.
  static TextStyle footerLabel(Color color) =>
      TextStyle(fontSize: 12, height: 1.2, color: color);

  /// The realised total: 18 px semibold, the largest figure on the card.
  static TextStyle footerTotal(Color color) => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.2,
    fontFeatures: _tabular,
    color: color,
  );

  /// A split pill in the footer.
  static TextStyle footerChip(Color color) => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    fontFeatures: _tabular,
    color: color,
  );

  /// The phone card's date, which the kit sets larger than a table row's.
  static TextStyle mobileDate(Color color) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: color,
  );

  /// A caption over a figure in the phone card's four-cell grid.
  static TextStyle mobileCaption(Color color) =>
      TextStyle(fontSize: 11, height: 1.2, color: color);

  /// The empty state's sentence.
  static TextStyle placeholder(Color color) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: color,
  );
}
