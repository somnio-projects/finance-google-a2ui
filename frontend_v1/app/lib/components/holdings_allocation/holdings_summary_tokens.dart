import 'package:flutter/material.dart';

/// The `HoldingsSummary` card's measured text palette and type scale (GGU-145).
///
/// **Read from Miriam's Figma**, section `HoldingsSummary` of
/// `figma.com/design/rFA8ZEEOOvnOyq7IrTObma/A2UI-FINANCE-UI-KIT`, on the
/// `Default, Light, Desktop` and `Default, Dark, Mobile` variants. The design
/// calls the two colours `text/primary` and `text/secondary`, and every piece
/// of copy on this card takes one of them.
///
/// It is a **second palette beside `ChartPalette`, on purpose and for now.**
/// `ChartPalette.title` is `#1A1B20` / `#E5E1E9`, taken from the mock this
/// repository generated before the designer had drawn anything; these are
/// `#242425` / `#FFFFFF`, read off the artboard. Reconciling them is a change
/// to every chart component at once, so it is recorded as an open decision in
/// `specs/frontend/0033` rather than smuggled in here — but a card that has
/// been measured does not go on quoting a mock while it waits.
@immutable
class HoldingsSummaryText {
  /// Creates a palette.
  const HoldingsSummaryText({required this.primary, required this.secondary});

  /// `text/primary` on the light artboard.
  static const Color lightPrimary = Color(0xFF242425);

  /// `text/secondary` on the light artboard.
  static const Color lightSecondary = Color(0xFF56575B);

  /// `text/primary` on the dark artboard.
  static const Color darkPrimary = Color(0xFFFFFFFF);

  /// `text/secondary` on the dark artboard.
  static const Color darkSecondary = Color(0xFFB9BEC6);

  /// `Default, Light, Desktop`.
  static const HoldingsSummaryText light = HoldingsSummaryText(
    primary: lightPrimary,
    secondary: lightSecondary,
  );

  /// `Default, Dark, Mobile`.
  static const HoldingsSummaryText dark = HoldingsSummaryText(
    primary: darkPrimary,
    secondary: darkSecondary,
  );

  /// Everything the reader is meant to land on: the title, the total, a lit
  /// segment's label.
  final Color primary;

  /// Everything that qualifies it: the total's caption, an unlit segment.
  final Color secondary;

  /// The palette matching [context]'s theme brightness.
  static HoldingsSummaryText of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// The card's title — `font-family/base`, SemiBold, 16 px, line height 20.
  static TextStyle title(Color color) => _style(color, 16, FontWeight.w600);

  /// The total inside the ring — SemiBold, 18 px, line height 20.
  static TextStyle total(Color color) => _style(color, 18, FontWeight.w600);

  /// Its caption under it — Regular, 14 px, line height 20.
  static TextStyle totalLabel(Color color) =>
      _style(color, 14, FontWeight.w400);

  /// Every line above shares one line height, which is what lets the total
  /// and its caption stack inside the ring without a gap between them.
  static const double lineHeight = 20;

  static TextStyle _style(Color color, double size, FontWeight weight) =>
      TextStyle(
        color: color,
        fontSize: size,
        fontWeight: weight,
        height: lineHeight / size,
      );
}
