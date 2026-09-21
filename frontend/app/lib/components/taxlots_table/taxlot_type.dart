import 'package:flutter/widgets.dart';

/// The type scale the tax-lot table draws with, **measured from the design**.
///
/// Sizes and weights are the artboard's. The *families* are not: the design
/// sets Inter for labels and Roboto Mono for figures, and this app bundles
/// no font. Spec `frontend/0002` OD-4 settled that for the waterfall —
/// `tabularFigures` on the bundled face buys the digit alignment a monospace
/// column needs without a 60 kB download — and this table follows it rather
/// than reopening the question (spec `frontend/0003` OD-6).
///
/// Every role is a **function of its colour**, because that is how all of
/// them are used: the size and weight belong to the design, the colour
/// belongs to `TaxLotPalette` and differs per artboard. Returning the style
/// already tinted keeps `.copyWith(color: …)` out of eleven call sites.
abstract final class TaxLotType {
  /// Figures line up column-wise without a monospaced family.
  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// A column header: `500 10px Inter`.
  static TextStyle columnHeader(Color color) => TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: color,
  );

  /// The card's caption, from the payload's `title`.
  static TextStyle title(Color color) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: color,
  );

  /// The line under it, from the payload's `subtitle`.
  static TextStyle subtitle(Color color) =>
      TextStyle(fontSize: 11, height: 1.2, color: color);

  /// A row's acquisition date: `400 11.5px Roboto`.
  static TextStyle date(Color color) =>
      TextStyle(fontSize: 11.5, height: 1.2, color: color);

  /// A money column: `400 11.5px Roboto Mono`.
  static TextStyle figure(Color color) => TextStyle(
    fontSize: 11.5,
    height: 1.2,
    fontFeatures: _tabular,
    color: color,
  );

  /// The gain/loss column, which the design sets a weight heavier.
  static TextStyle figureEmphasis(Color color) => TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    height: 1.2,
    fontFeatures: _tabular,
    color: color,
  );

  /// A term pill inside a row: `500 9.5px Inter`.
  static TextStyle rowChip(Color color) => TextStyle(
    fontSize: 9.5,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: color,
  );

  /// A term pill in the legend: `500 10px Inter`.
  static TextStyle legendChip(Color color) => TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: color,
  );

  /// A split pill in the footer: `500 10.5px Inter`.
  static TextStyle footerChip(Color color) => TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    height: 1.2,
    fontFeatures: _tabular,
    color: color,
  );

  /// The footer's caption: `400 11px Inter`.
  static TextStyle footerLabel(Color color) =>
      TextStyle(fontSize: 11, height: 1.2, color: color);

  /// The realised total: `500 17px Roboto`.
  static TextStyle footerTotal(Color color) => TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    height: 1.2,
    fontFeatures: _tabular,
    color: color,
  );

  /// The empty state's sentence: `500 13px Roboto`.
  static TextStyle placeholder(Color color) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: color,
  );
}
