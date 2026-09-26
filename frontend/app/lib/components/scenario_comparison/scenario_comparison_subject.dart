import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_model.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_text.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_tokens.dart';
import 'package:flutter/material.dart';

/// A caption above a figure, in the design's eyebrow-over-value pairing.
///
/// [caption] is always client copy — a field name — and [value] is always a
/// string the backend formatted. Keeping them in one widget is what stops
/// the two being concatenated into a single `Text`, which is where a
/// "$64,250.00 unit price" would quietly become client-composed prose.
class ScenarioFact extends StatelessWidget {
  /// Creates a fact.
  const ScenarioFact({required this.caption, required this.value, super.key});

  /// The field's name, e.g. `Unit price`. Client copy.
  final String caption;

  /// The backend's display string, rendered verbatim (N-1).
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final tokens = ScenarioComparisonTokens.of(context);
    return Semantics(
      container: true,
      label: '$caption $value',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              caption,
              style: ScenarioComparisonText.caption(tokens.caption),
            ),
            const SizedBox(height: 2),
            Text(value, style: ScenarioComparisonText.value(palette.title)),
          ],
        ),
      ),
    );
  }
}

/// The sale every column is costed against, rendered once.
///
/// The design's own card puts a sale in its eyebrow — *"default · sell 200
/// NVDA · 2 strategies"* — as one uppercased mono line. This renders the
/// same four facts as caption/value pairs instead, for two reasons that are
/// both contract rather than taste:
///
/// 1. The eyebrow's uppercase is a CSS `text-transform`. Applying
///    `toUpperCase()` to `subject.symbol` or `subject.label` would be the
///    client altering strings the backend wrote (N-1, N-9).
/// 2. That eyebrow is gallery chrome — the sibling cards in the same
///    artboard read *"3-scenario variant"* and *"loading · skeleton
///    columns"* in the same slot — so it is a caption about the artboard,
///    not a component surface with a field behind each word.
///
/// `specs/frontend/0004` OD-4 records it.
class ScenarioComparisonSubject extends StatelessWidget {
  /// Creates the subject strip.
  const ScenarioComparisonSubject({required this.subject, super.key});

  /// The sale being costed.
  final ScenarioSubject subject;

  /// The captions, which are field names rather than payload text — the
  /// contract carries no label for any of the four (`specs/frontend/0004`
  /// OD-1).
  static const String symbolCaption = 'Symbol';

  /// The caption above `subject.quantity_display`.
  static const String quantityCaption = 'Quantity';

  /// The caption above `subject.price.display`.
  static const String priceCaption = 'Unit price';

  /// The caption above `subject.proceeds.display`.
  static const String proceedsCaption = 'Proceeds';

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 22,
    runSpacing: 10,
    children: <Widget>[
      ScenarioFact(caption: symbolCaption, value: subject.symbol),
      ScenarioFact(caption: quantityCaption, value: subject.quantityDisplay),
      ScenarioFact(caption: priceCaption, value: subject.priceDisplay),
      ScenarioFact(caption: proceedsCaption, value: subject.proceedsDisplay),
    ],
  );
}
