import 'package:flutter/material.dart';

/// The type the multi-leg ticket is set in, measured from the catalog page.
///
/// The design sets its figures in Roboto Mono; this app bundles no mono face
/// and buys the digit alignment with `tabularFigures`, the deviation
/// `ChartText` records (spec frontend/0002). Sizes and weights are the
/// artboard's own.
abstract final class OrderTicketV2Text {
  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// The header caption: `subtag` — 600 · 10 px · `.08em` · uppercase.
  static TextStyle caption(Color color) => TextStyle(
    color: color,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    fontFeatures: _tabular,
  );

  /// A header pill: 500 · 10 px.
  static TextStyle pill(Color color) =>
      TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500);

  /// A leg's ticker: 600 · 13 px.
  static TextStyle symbol(Color color) =>
      TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600);

  /// `@ $1,204.66` beside the ticker: 400 · 10.5 px, mono.
  static TextStyle price(Color color) => TextStyle(
    color: color,
    fontSize: 10.5,
    fontWeight: FontWeight.w400,
    fontFeatures: _tabular,
  );

  /// A leg's amount: 600 · 14 px, mono.
  static TextStyle amount(Color color) => TextStyle(
    color: color,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    fontFeatures: _tabular,
  );

  /// The stepper's share count: 500 · 12 px, mono.
  static TextStyle quantity(Color color) => TextStyle(
    color: color,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontFeatures: _tabular,
  );

  /// The stepper's `-` and `+`: 500 · 15 px.
  static TextStyle step(Color color) =>
      TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w500);

  /// The weight beside the bar: 600 · 11.5 px, mono.
  static TextStyle weight(Color color) => TextStyle(
    color: color,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    fontFeatures: _tabular,
  );

  /// A panel figure's label: 400 · 10 px.
  static TextStyle figureLabel(Color color) =>
      TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w400);

  /// A panel figure: 600 · 16 px, mono.
  static TextStyle figure(Color color) => TextStyle(
    color: color,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontFeatures: _tabular,
  );

  /// The weight row's label: 500 · 11 px.
  static TextStyle shiftLabel(Color color) =>
      TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500);

  /// The weight row's `before` and the arrow: 500 · 12 px, mono.
  static TextStyle shiftBefore(Color color) => TextStyle(
    color: color,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontFeatures: _tabular,
  );

  /// The weight row's `after`: 600 · 12.5 px, mono.
  static TextStyle shiftAfter(Color color) => TextStyle(
    color: color,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    fontFeatures: _tabular,
  );

  /// The validation sentence: 500 · 11.5 px / 1.35.
  static TextStyle notice(Color color) => TextStyle(
    color: color,
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  /// `Review order`: 500 · 14 px.
  static TextStyle button(Color color) =>
      TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500);

  /// `Save as draft`: 500 · 13 px.
  static TextStyle link(Color color) =>
      TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500);
}
