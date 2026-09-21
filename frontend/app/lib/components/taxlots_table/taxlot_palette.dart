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
/// "gain" and "loss" are semantic roles a tax-lot table needs and a generated
/// scheme has no slot for; deriving them from a seed would also throw away
/// the design's measured values.
@immutable
class TaxLotPalette {
  /// Creates a palette. Every colour is required — a table with a missing
  /// role would fall back to something nobody chose.
  const TaxLotPalette({
    required this.surface,
    required this.border,
    required this.selectedSurface,
    required this.selectedAccent,
    required this.footerSurface,
    required this.primaryText,
    required this.figureText,
    required this.labelText,
    required this.mutedText,
    required this.gain,
    required this.loss,
    required this.checkboxBorder,
    required this.checkboxGlyph,
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

  /// The card, and the fill of an unselected row.
  final Color surface;

  /// The hairline around the card, a row and the footer.
  final Color border;

  /// The fill of a row the sale fully consumes.
  final Color selectedSurface;

  /// That row's hairline and its ticked box.
  final Color selectedAccent;

  /// The realised-result bar at the foot of the card.
  final Color footerSurface;

  /// Dates, the title and the figure the design emphasises.
  final Color primaryText;

  /// A supporting figure — cost basis and proceeds.
  final Color figureText;

  /// The footer's caption and the empty state's sentence.
  final Color labelText;

  /// Column headers and a row's holding-period text.
  final Color mutedText;

  /// A lot the backend marked `trend: up`.
  final Color gain;

  /// A lot the backend marked `trend: down`.
  final Color loss;

  /// The empty box on a row the sale does not fully consume.
  final Color checkboxBorder;

  /// The tick drawn inside a filled box.
  final Color checkboxGlyph;

  /// The dashed square the empty state shows.
  final Color placeholderBorder;

  /// Amber — a lot held less than a year.
  final TaxLotTermColors shortTerm;

  /// Teal — a lot held a year or more.
  final TaxLotTermColors longTerm;
}
