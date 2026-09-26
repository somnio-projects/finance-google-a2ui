import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_footer.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_layout.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_model.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_subject.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_table.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_text.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_tokens.dart';
import 'package:flutter/material.dart';

/// Renders `scenario.comparison.v1` as the design's card.
///
/// The chrome is measured from the designer's rendered DOM and is the same
/// chrome `AttributionWaterfallCard` wears, to the pixel except for one: a
/// 16 px radius, a 1 px hairline, and 18/16/18/**15** padding — the
/// comparison card's bottom inset is a pixel deeper than the waterfall's.
/// The two constants are asserted in
/// `scenario_comparison_card_test.dart` rather than trusted.
///
/// Reading order down the card: what is being sold, then what each method
/// makes of it, then how far apart the outcomes are, then the notes. That is
/// also the payload's own order.
///
/// **Colour carries no meaning here.** The design's shared token legend has
/// a green *Gain ▲* and a red *Loss ▼*, and this card uses neither: every
/// figure is drawn in the primary text colour. `scenario.comparison.v1`
/// carries no `direction` enum — unlike `attribution.waterfall.v1`, whose
/// buckets do — and the only other way to choose a colour would be to look
/// at the sign inside `"+$3,825.00"`, which is the client reading a figure
/// out of a formatted string (N-1). `specs/frontend/0004` OD-7 raises the
/// missing field.
class ScenarioComparisonCard extends StatelessWidget {
  /// Creates the card.
  const ScenarioComparisonCard({required this.data, super.key});

  /// The card's corner radius, measured from the design.
  static const double radius = ScenarioComparisonLayout.cardRadius;

  /// The card's padding, measured from the design.
  static const EdgeInsets padding = ScenarioComparisonLayout.cardPadding;

  /// What to draw.
  final ScenarioComparisonData data;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final tokens = ScenarioComparisonTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        // Plus the hairline on all four edges: the design's border sits
        // inside its declared width and Flutter's does not
        // ([ScenarioComparisonLayout.hairline]).
        padding:
            padding + const EdgeInsets.all(ScenarioComparisonLayout.hairline),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _TitleRow(
              title: data.title,
              subjectLabel: data.subject.label,
              badge: data.summary.badge,
              palette: palette,
              tokens: tokens,
            ),
            const SizedBox(height: 12),
            ScenarioComparisonSubject(subject: data.subject),
            const SizedBox(height: 16),
            ScenarioComparisonTable(
              columns: data.columns,
              metrics: data.metrics,
            ),
            const SizedBox(height: 12),
            ScenarioComparisonFooter(
              spread: data.spread,
              notes: data.notes,
              summary: data.summary.text,
            ),
          ],
        ),
      ),
    );
  }
}

/// The card's caption, with the position it is about on the right.
///
/// The design's preview has no title in this slot — its top row is the
/// gallery's own eyebrow and the "best on that row" legend, both of which
/// are chrome around the component rather than fields of it. The contract
/// makes `title` **required**, so dropping it is not an option, and it is
/// drawn in the type `AttributionWaterfallCard` already uses for a card
/// caption so the two cards read as one set (`specs/frontend/0004` OD-4).
class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.title,
    required this.subjectLabel,
    required this.badge,
    required this.palette,
    required this.tokens,
  });

  final String title;
  final String subjectLabel;

  /// The pill the frame draws top-right, server-written (N-9).
  final String badge;
  final ChartPalette palette;
  final ScenarioComparisonTokens tokens;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: <Widget>[
      Expanded(child: Text(title, style: ChartText.title(palette.title))),
      const SizedBox(width: 12),
      Text(subjectLabel, style: ScenarioComparisonText.caption(tokens.caption)),
      const SizedBox(width: 8),
      DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.verdict.winnerSurface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            badge,
            style: ScenarioComparisonText.caption(tokens.verdict.winnerAccent),
          ),
        ),
      ),
    ],
  );
}
