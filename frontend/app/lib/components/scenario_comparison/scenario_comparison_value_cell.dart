import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_layout.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_tokens.dart';
import 'package:flutter/material.dart';

/// One figure in the comparison grid, tinted and ticked when it wins its row.
///
/// [isWinner] is handed down, never worked out: the backend names the winning
/// column in `rows[].winner` and the table matches it by **key**. This widget
/// holds no figure it could compare — `display` is a string the backend
/// formatted, and there is no raw member on this card at all (N-2, N-4).
///
/// Its own file because the table is at the file budget and because the tick
/// is the one thing in this component that is drawn rather than laid out.
class ScenarioValueCell extends StatelessWidget {
  /// Creates a cell.
  const ScenarioValueCell({
    required this.display,
    required this.isWinner,
    required this.palette,
    required this.tokens,
    super.key,
  });

  /// The backend's own formatted string, rendered verbatim (N-1).
  final String display;

  /// Whether the backend named this column the winner of this row.
  final bool isWinner;

  /// The chart palette, for the figure's colour.
  final ChartPalette palette;

  /// The card's own tokens, for the winning cell's tint.
  final ScenarioComparisonTokens tokens;

  /// The tick's diameter, measured from the design.
  static const double tickSize = 18;

  /// What a screen reader hears on a marked cell, so the tint is not the
  /// only way to know which column won.
  static const String winnerLabel = 'best in this row';

  @override
  Widget build(BuildContext context) {
    final figure = Text(
      display,
      textAlign: TextAlign.end,
      style: ScenarioComparisonText.value(palette.title),
    );
    if (!isWinner) {
      return Padding(
        padding: ScenarioComparisonLayout.valueCellPadding,
        child: figure,
      );
    }
    return Semantics(
      label: '$display, $winnerLabel',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.winnerSurface,
          borderRadius: BorderRadius.circular(
            ScenarioComparisonLayout.headerCellRadius,
          ),
        ),
        child: Padding(
          padding: ScenarioComparisonLayout.valueCellPadding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Icon(
                Icons.check_circle,
                size: tickSize,
                color: tokens.winnerTick,
              ),
              const SizedBox(width: 6),
              Flexible(child: figure),
            ],
          ),
        ),
      ),
    );
  }
}
