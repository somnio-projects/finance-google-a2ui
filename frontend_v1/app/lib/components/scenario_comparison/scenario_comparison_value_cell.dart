import 'package:finance_app/components/scenario_comparison/scenario_comparison_text.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_tokens.dart';
import 'package:flutter/material.dart';

/// One figure in the comparison grid, marked when it wins its row.
///
/// [isWinner] is handed down, never worked out: the backend names the winning
/// column in `rows[].winner` and the table matches it by **key**. This widget
/// holds no figure it could compare — `display` is a string the backend
/// formatted, and there is no raw member on this card at all (N-2, N-4).
///
/// **Every value here is measured**, from the catalog mock's rendered DOM
/// (`Catalog_ScenarioComparison.dc.html`) at the 1024 artboard, the way
/// `scenario_comparison_geometry_test.dart` measured the grid. The first
/// version of this widget guessed them, and every one of the four was wrong:
/// the tint was a shade off, there was no border, the figure kept its normal
/// colour and weight, and the tick was a Material icon rather than the
/// design's filled disc.
class ScenarioValueCell extends StatelessWidget {
  /// Creates a cell.
  const ScenarioValueCell({
    required this.display,
    required this.isWinner,
    required this.tokens,
    super.key,
  });

  /// The backend's own formatted string, rendered verbatim (N-1).
  final String display;

  /// Whether the backend named this column the winner of this row.
  final bool isWinner;

  /// The card's measured palette.
  final ScenarioComparisonTokens tokens;

  /// The tick's diameter: `width:15px;height:15px;border-radius:50%`.
  static const double tickSize = 15;

  /// The gap between the tick and the figure: `gap:6px`.
  static const double tickGap = 6;

  /// `padding:9px 10px` on every cell, winner or not, so a marked cell does
  /// not shift the column it sits in.
  static const EdgeInsets cellPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 9,
  );

  /// `border-radius:8px` — not the header's 10, and not a coincidence: the
  /// header's radius is top-only and larger.
  static const double cellRadius = 8;

  /// The check's own size inside the disc.
  ///
  /// The design writes the mark as the character `✓` at `700 9px`. It is
  /// drawn here as `Icons.check` instead, because that glyph is **not in
  /// Roboto**: rendered from the text stack it comes out as a filled
  /// replacement box, which is what the first render of this cell showed.
  /// The shape is the design's; the delivery mechanism is not, and it
  /// cannot be.
  static const double tickGlyphSize = 11;

  /// What a screen reader hears on a marked cell, so the tint is not the
  /// only way to know which column won.
  static const String winnerLabel = 'best in this row';

  @override
  Widget build(BuildContext context) {
    final figure = Text(
      display,
      textAlign: TextAlign.end,
      style: ScenarioComparisonText.value(
        isWinner ? tokens.verdict.winnerAccent : tokens.figure,
      ).copyWith(fontWeight: isWinner ? FontWeight.w600 : FontWeight.w400),
    );
    final row = Padding(
      padding: cellPadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          if (isWinner) ...<Widget>[
            _Tick(tokens: tokens),
            const SizedBox(width: tickGap),
          ],
          Flexible(child: figure),
        ],
      ),
    );
    if (!isWinner) return row;
    return Semantics(
      label: '$display, $winnerLabel',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.verdict.winnerSurface,
          border: Border.all(color: tokens.verdict.winnerBorder),
          borderRadius: BorderRadius.circular(cellRadius),
        ),
        child: row,
      ),
    );
  }
}

/// The design's tick: a filled disc with a white check, not an icon.
class _Tick extends StatelessWidget {
  const _Tick({required this.tokens});

  final ScenarioComparisonTokens tokens;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: tokens.verdict.winnerAccent,
      shape: BoxShape.circle,
    ),
    child: SizedBox.square(
      dimension: ScenarioValueCell.tickSize,
      child: Center(
        child: Icon(
          Icons.check,
          size: ScenarioValueCell.tickGlyphSize,
          color: tokens.verdict.winnerTickGlyph,
        ),
      ),
    ),
  );
}
