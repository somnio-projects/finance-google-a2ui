import 'package:flutter/material.dart';

/// The four colours one holding-period term is drawn with.
///
/// Short-term and long-term are the only semantic roles this table adds to
/// the palette, and each needs the same four values: the rail down the left
/// of a row, and the three that make its pill. Grouping them keeps
/// `TaxLotPalette` readable and makes "a term has a colour" a single idea
/// rather than eight parallel fields that can drift apart.
///
/// The semantics come from the catalog index's shared token legend —
/// short-term amber, long-term teal — not from this table's own page, so the
/// two cannot disagree.
@immutable
class TaxLotTermColors {
  /// Creates the colours for one term.
  const TaxLotTermColors({
    required this.accent,
    required this.chipForeground,
    required this.chipBackground,
    required this.chipBorder,
  });

  /// The 3 px rail down the left edge of a row with this term.
  final Color accent;

  /// The pill's text.
  final Color chipForeground;

  /// The pill's fill.
  final Color chipBackground;

  /// The hairline around a legend pill.
  ///
  /// Only the legend draws it: the pill inside a row is unbordered, which is
  /// what distinguishes the key at the top of the card from the term marker
  /// on each line.
  final Color chipBorder;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxLotTermColors &&
          other.accent == accent &&
          other.chipForeground == chipForeground &&
          other.chipBackground == chipBackground &&
          other.chipBorder == chipBorder;

  @override
  int get hashCode =>
      Object.hash(accent, chipForeground, chipBackground, chipBorder);
}
