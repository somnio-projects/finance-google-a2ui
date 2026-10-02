import 'package:flutter/material.dart';

/// The three colours one holding-period term is drawn with.
///
/// Short-term and long-term are the only semantic roles this table adds to
/// the palette, and each needs the same three values: the rail down the left
/// of a row, and the two that make its pill. Grouping them keeps
/// `TaxLotPalette` readable and makes "a term has a colour" a single idea
/// rather than six parallel fields that can drift apart.
///
/// The UI Kit's pills carry **no hairline** — the fourth colour this class
/// used to hold went with the bordered legend pill of the first artboard
/// (spec `frontend/0027` OD-5). A pill is a fill and a word.
@immutable
class TaxLotTermColors {
  /// Creates the colours for one term.
  const TaxLotTermColors({
    required this.accent,
    required this.chipForeground,
    required this.chipBackground,
  });

  /// The 4 px rail down the left edge of a row with this term.
  ///
  /// The one value the designer holds **across both themes** — see
  /// `TaxLotTokens`, where a test asserts it rather than leaving it looking
  /// like a copy-paste.
  final Color accent;

  /// The pill's text.
  final Color chipForeground;

  /// The pill's fill.
  final Color chipBackground;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxLotTermColors &&
          other.accent == accent &&
          other.chipForeground == chipForeground &&
          other.chipBackground == chipBackground;

  @override
  int get hashCode => Object.hash(accent, chipForeground, chipBackground);
}
