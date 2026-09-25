import 'package:finance_app/components/taxlots_table/taxlot_term_colors.dart';
import 'package:finance_app/components/taxlots_table/taxlot_tokens.dart';
import 'package:flutter/material.dart';

/// The colours the tax-lot table is drawn with, in one brightness.
///
/// A plain immutable class rather than a `ThemeExtension`, deliberately.
/// Registering an extension means editing `AppTheme`, and *adding a component
/// edits no existing file* (ADR-L D-3) is a claim about the whole path to the
/// screen, not only about the registry. [of] reads the brightness the theme
/// already carries, which needs nothing registered.
///
/// Material 3's `ColorScheme` cannot supply these. "Short-term", "long-term",
/// "gain", "loss" and "a lot this sale consumes" are semantic roles a tax-lot
/// table needs and a generated scheme has no slot for; deriving them from a
/// seed would also throw away the design's measured values.
@immutable
class TaxLotPalette {
  /// Creates a palette. Every colour is required — a table with a missing
  /// role would fall back to something nobody chose.
  const TaxLotPalette({
    required this.surface,
    required this.shadow,
    required this.divider,
    required this.selectedRow,
    required this.checkedBox,
    required this.checkGlyph,
    required this.checkboxBorder,
    required this.primaryText,
    required this.mutedText,
    required this.gain,
    required this.loss,
    required this.placeholderBorder,
    required this.shortTerm,
    required this.longTerm,
  });

  /// The palette for the brightness [context] is themed in.
  ///
  /// Both artboards draw identical geometry and differ only in colour, which
  /// is why one widget tree serves them both.
  static TaxLotPalette of(BuildContext context) =>
      TaxLotTokens.forBrightness(Theme.of(context).brightness);

  /// The card. The UI Kit draws **no hairline** around it — it is a white
  /// (or near-black) plane lifted off the page by [shadow].
  final Color surface;

  /// That lift.
  final Color shadow;

  /// The one rule on the card: between the last row and the footer.
  final Color divider;

  /// The tint of a row whose lot the sale consumes whole (`fully_sold`).
  final Color selectedRow;

  /// The fill of that row's tick box.
  final Color checkedBox;

  /// The tick inside it.
  final Color checkGlyph;

  /// The hairline of an unticked box.
  final Color checkboxBorder;

  /// Dates, shares, and both money columns.
  final Color primaryText;

  /// Column captions, the subtitle, the footer's caption.
  final Color mutedText;

  /// A lot the backend marked `trend: up`. The footer's split pills take
  /// their term's colours instead, not this one.
  final Color gain;

  /// A lot the backend marked `trend: down`.
  final Color loss;

  /// The dashed square the empty state shows.
  final Color placeholderBorder;

  /// Amber — a lot held less than a year.
  final TaxLotTermColors shortTerm;

  /// Teal — a lot held a year or more.
  final TaxLotTermColors longTerm;
}
