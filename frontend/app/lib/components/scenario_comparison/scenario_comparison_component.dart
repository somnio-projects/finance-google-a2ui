import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_card.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_model.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_rows.dart';
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
/// **The card names no winner.** The design ships `recommended` and
/// `metrics[].betterWhen`; the contract ships neither, deliberately — spec
/// `backend/0017` OD-4 is that picking a lot-selection method for someone is
/// tax advice. `specs/frontend/0003` OD-3 records the divergence.
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
            method: column.text('method'),
            label: column.text('label'),
          ),
      ],
      metrics: _metrics(columns),
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

  /// Transposes [columns] into the design's four metric rows.
  ///
  /// Written out four times rather than looped over a list of paths on
  /// purpose: every payload path in this app is a **literal**, and
  /// `binding_rules_test.dart::payload paths are literals, never variables`
  /// fails on a reader whose argument does not open with a quote (N-5).
  ///
  /// The row names are client copy, because the contract has no metric list
  /// to take them from — `specs/frontend/0003` OD-1. The order is the order
  /// a reader works down: what the sale cost, what it realised, then how
  /// that result splits by holding period.
  List<ScenarioMetricRow> _metrics(List<ViewPayload> columns) =>
      <ScenarioMetricRow>[
        ScenarioMetricRow(
          label: 'Cost basis',
          valueDisplays: <String>[
            for (final column in columns) column.text('cost_basis.display'),
          ],
        ),
        ScenarioMetricRow(
          label: 'Realized P/L',
          valueDisplays: <String>[
            for (final column in columns) column.text('realized_pl.display'),
          ],
        ),
        ScenarioMetricRow(
          label: 'Short-term',
          valueDisplays: <String>[
            for (final column in columns) column.text('short_term_pl.display'),
          ],
        ),
        ScenarioMetricRow(
          label: 'Long-term',
          valueDisplays: <String>[
            for (final column in columns) column.text('long_term_pl.display'),
          ],
        ),
      ];
}

/// Adds this component to [registry].
///
/// Called only from the generated `component_manifest.g.dart`. Every
/// component module exposes exactly one `register`, which is what
/// `binding_rules_test.dart` checks and what makes discovery unambiguous.
void register(ComponentRegistry registry) =>
    registry.register(const ScenarioComparisonComponent());
