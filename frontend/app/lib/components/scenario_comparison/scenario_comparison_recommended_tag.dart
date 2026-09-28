import 'package:finance_app/components/scenario_comparison/scenario_comparison_text.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_tokens.dart';
import 'package:flutter/material.dart';

/// The `★ Recommended` pill on the recommended column's header.
///
/// Measured from the catalog mock's rendered DOM: `border-radius:20px`,
/// `padding:2px 8px`, `margin-top:2px`, and a `600 9px` label tracked at
/// `.04em` — which is `letterSpacing: 0.36` at that size.
///
/// **Two things the design does that this widget deliberately does not.**
/// The CSS uppercases the label with `text-transform`, and it writes the
/// star into the string. Both would be the client editing a value the
/// backend formatted (N-1, N-9), so the label renders exactly as it arrives
/// and the star is a drawn icon beside it.
class ScenarioRecommendedTag extends StatelessWidget {
  /// Creates the tag for [label].
  const ScenarioRecommendedTag({
    required this.label,
    required this.tokens,
    super.key,
  });

  /// `columns[].recommendation_label`, rendered verbatim.
  final String label;

  /// The card's measured palette.
  final ScenarioComparisonTokens tokens;

  /// The star's size, matched to the label's 9 px.
  static const double starSize = 9;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.verdict.recommendedTagSurface,
        border: Border.all(color: tokens.verdict.recommendedTagBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.star,
              size: starSize,
              color: tokens.verdict.recommendedText,
            ),
            const SizedBox(width: 3),
            // Flexible so a narrow track wraps the label rather than
            // overflowing it. Truncating is not an option — the tag is a
            // server-written string and N-9 renders it whole.
            Flexible(
              child: Text(
                label,
                style: ScenarioComparisonText.recommendedTag(
                  tokens.verdict.recommendedText,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
