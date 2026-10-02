import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_card.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_metrics.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_model.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_rows.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_skeleton.dart';
import 'package:finance_app/components/view_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/widgets.dart';

/// Binds `scenario.comparison.v1` — the same sale costed under each
/// lot-selection method, side by side.
///
/// Field paths come from the backend's generated catalog entry, and
/// `app/test/architecture/catalog_contract_test.dart` checks [viewId] and
/// [a2uiComponent] against `view-catalog.snapshot.json`, so the rename this
/// component already survived once — the design index still calls it
/// `ComparisonCard` while the backend emits `ScenarioComparison` — turns the
/// suite red rather than showing a placeholder.
///
/// **Nothing here computes.** A comparison card is where "just subtract the
/// two" is most tempting, and the answer is that the difference between two
/// scenarios is `spread`, which the backend already measured and formatted.
/// No raw `*.amount` member is read at all: this card draws no chart, so it
/// has no use for the geometry seam either (N-2, N-4).
///
/// **The card names a winner now, and it reads one rather than picking one.**
/// It used to ship neither `recommended` nor a per-row direction, because
/// spec `backend/0017` OD-4 held that choosing a lot method for someone is
/// tax advice — right while there was no declared rate to rank by. Backend
/// spec 0051 made the rate a printed, bounded option, so the ranking became
/// arithmetic the reader can check, and the server performs it: `rows[]`
/// carries the winner and `columns[].recommended` the tag. Comparing two
/// figures here would still be N-2, and this card holds no raw member to
/// compare with.
class ScenarioComparisonComponent extends ViewComponent {
  /// Creates the component.
  const ScenarioComparisonComponent();

  @override
  String get viewId => 'scenario.comparison.v1';

  @override
  String get a2uiComponent => 'ScenarioComparison';

  @override
  Widget build(BuildContext context, ViewPayload payload) =>
      ScenarioComparisonCard(data: read(payload));

  @override
  Widget skeleton(BuildContext context) => const ScenarioComparisonSkeleton();

  /// Reads [payload] into the model the card draws.
  ///
  /// Exposed so the binding can be asserted without a widget tree, and so a
  /// golden can pump the card from the catalog's own published example.
  ScenarioComparisonData read(ViewPayload payload) {
    // Read once: `metrics` transposes the same rows the columns come from,
    // and asking the payload twice would let the two disagree.
    final columns = payload.rows('columns');
    return ScenarioComparisonData(
      title: payload.text('title'),
      subject: ScenarioSubject(
        label: payload.text('subject.label'),
        symbol: payload.text('subject.symbol'),
        quantityDisplay: payload.text('subject.quantity_display'),
        priceDisplay: payload.text('subject.price.display'),
        proceedsDisplay: payload.text('subject.proceeds.display'),
      ),
      columns: <ScenarioColumn>[
        for (final column in columns)
          ScenarioColumn(
            key: column.text('key'),
            method: column.text('method'),
            kind: column.text('kind'),
            label: column.text('label'),
            caption: column.text('caption'),
            recommended: column.flag('recommended'),
            recommendationLabel: column.optionalText('recommendation_label'),
          ),
      ],
      metrics: scenarioMetrics(payload, columns),
      summary: ScenarioSummary(
        badge: payload.text('summary.badge'),
        text: payload.text('summary.text'),
      ),
      spread: ScenarioSpread(
        amountDisplay: payload.text('spread.amount.display'),
        // Optional by contract: the backend names neither end when the
        // methods coincide (spec `backend/0017` AC-6).
        highest: payload.optionalText('spread.highest'),
        lowest: payload.optionalText('spread.lowest'),
      ),
      notes: <ScenarioNote>[
        for (final note in payload.rows('notes'))
          ScenarioNote(label: note.text('label'), text: note.text('text')),
      ],
    );
  }
}

/// Adds this component to [registry].
///
/// Called only from the generated `component_manifest.g.dart`. Every
/// component module exposes exactly one `register`, which is what
/// `binding_rules_test.dart` checks and what makes discovery unambiguous.
void register(ComponentRegistry registry) =>
    registry.register(const ScenarioComparisonComponent());
