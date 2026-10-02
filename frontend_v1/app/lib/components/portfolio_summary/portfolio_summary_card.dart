import 'package:finance_app/components/portfolio_summary/home_hero.dart';
import 'package:finance_app/components/portfolio_summary/home_movers.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// The summary as a card in the transcript: Home's hero over Home's movers.
///
/// [rejection] is the agent's own sentence for a refused range — the
/// designed error state of an edit (spec `frontend_v1/0001` AC-5) — drawn
/// under the hero, verbatim.
class PortfolioSummaryCard extends StatelessWidget {
  /// Creates the card.
  const PortfolioSummaryCard({
    required this.payload,
    required this.range,
    this.loading = false,
    this.rejection,
    this.onRangeSelected,
    super.key,
  });

  /// `portfolio.summary.v1`.
  final ViewPayload payload;

  /// The selected range code.
  final String range;

  /// Whether a range is being re-rendered.
  final bool loading;

  /// Why the last range was refused, or null.
  final String? rejection;

  /// Called with a tapped range; null keeps the selector read-only.
  final ValueChanged<String>? onRangeSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          HomeHero(
            payload: payload,
            range: range,
            loading: loading,
            onRangeSelected: onRangeSelected ?? _ignore,
          ),
          if (rejection != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              rejection!,
              style: TextStyle(fontSize: 12.5, color: tokens.loss),
            ),
          ],
          const SizedBox(height: 18),
          HomeMovers(payload: payload),
        ],
      ),
    );
  }

  static void _ignore(String _) {}
}
