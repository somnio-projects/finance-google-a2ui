import 'package:finance_app/components/scenario_comparison/scenario_comparison_layout.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_text.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_tokens.dart';
import 'package:flutter/material.dart';

/// The frame's footer sentence, above the spread.
///
/// It carries two figures and arrives with both already in it: the backend
/// composes it so nothing here assembles prose around numbers (N-9, backend
/// spec 0051 OD-5). Its own file for the file budget.
class ScenarioSummaryBanner extends StatelessWidget {
  /// Creates the banner.
  const ScenarioSummaryBanner({
    required this.text,
    required this.tokens,
    super.key,
  });

  /// The sentence, rendered verbatim.
  final String text;

  /// The card's tokens, for the tint it shares with a winning cell.
  final ScenarioComparisonTokens tokens;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.verdict.winnerSurface,
        borderRadius: BorderRadius.circular(
          ScenarioComparisonLayout.headerCellRadius,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          text,
          style: ScenarioComparisonText.caption(tokens.verdict.winnerAccent),
        ),
      ),
    ),
  );
}
