import 'package:finance_app/components/scenario_comparison/scenario_comparison_layout.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_rows.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_subject.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_tokens.dart';
import 'package:flutter/material.dart';

/// The spread, then every note the backend attached.
///
/// **The spread is the card's one cross-column figure and the client
/// computes no part of it.** `spread.amount.display` arrives formatted and
/// the two ends arrive as method tokens. This is the exact spot where
/// "just subtract the two columns" would be written, and the reason it is
/// not is N-2: a difference between scenarios is a figure the backend owns.
///
/// Naming the ends is not a ranking — spec `backend/0017` OD-4 argues that a
/// larger realised gain is not reliably the better outcome, because which
/// one is preferable depends on a marginal rate and a jurisdiction nothing
/// here knows. The card says where the ends are and stops.
class ScenarioComparisonFooter extends StatelessWidget {
  /// Creates the footer.
  const ScenarioComparisonFooter({
    required this.spread,
    required this.notes,
    super.key,
  });

  /// The caption above `spread.amount.display`. Client copy.
  static const String spreadCaption = 'Spread';

  /// The caption above `spread.highest`.
  static const String highestCaption = 'Highest realized';

  /// The caption above `spread.lowest`.
  static const String lowestCaption = 'Lowest realized';

  /// What the footer says when the methods coincide.
  ///
  /// Shown instead of the two ends, never beside a name picked out of a
  /// tie (spec `backend/0017` AC-6).
  static const String noDifference =
      'Every method compared produces the same realized result.';

  /// The difference between the extremes, as the backend measured it.
  final ScenarioSpread spread;

  /// The backend's notes, rendered verbatim and never dropped (N-9).
  final List<ScenarioNote> notes;

  @override
  Widget build(BuildContext context) {
    final tokens = ScenarioComparisonTokens.of(context);
    final highest = spread.highest;
    final lowest = spread.lowest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: tokens.rowRule)),
          ),
          child: Padding(
            // 11 px measured, plus the rule above it (see
            // [ScenarioComparisonLayout.hairline]).
            padding: const EdgeInsets.only(
              top: 11 + ScenarioComparisonLayout.hairline,
            ),
            child: Wrap(
              spacing: 22,
              runSpacing: 10,
              children: <Widget>[
                ScenarioFact(
                  caption: spreadCaption,
                  value: spread.amountDisplay,
                ),
                // Each end that is present, independently: the contract
                // makes the two `default null` separately, so requiring
                // both would leave a permitted payload undefined on screen.
                // The predicate lives once, on the model.
                if (highest != null)
                  ScenarioFact(caption: highestCaption, value: highest),
                if (lowest != null)
                  ScenarioFact(caption: lowestCaption, value: lowest),
                if (!spread.namesAnyEnd)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      noDifference,
                      style: ScenarioComparisonText.metricLabel(
                        tokens.metricLabel,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        for (final note in notes) _Note(note: note, tokens: tokens),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.note, required this.tokens});

  final ScenarioNote note;
  final ScenarioComparisonTokens tokens;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Semantics(
      container: true,
      label: '${note.label}. ${note.text}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              note.label,
              style: ScenarioComparisonText.caption(tokens.caption),
            ),
            const SizedBox(height: 2),
            Text(
              note.text,
              style: ScenarioComparisonText.columnLabel(tokens.metricLabel),
            ),
          ],
        ),
      ),
    ),
  );
}
