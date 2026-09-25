import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_card.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_data.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_skeleton.dart';
import 'package:finance_app/components/view_component.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/widgets.dart';

/// Binds `taxlots.table.v1` — the lots a proposed sale consumes.
///
/// Field paths come from the backend's generated catalog entry, and
/// `app/test/architecture/catalog_contract_test.dart` checks this class's
/// [viewId] and [a2uiComponent] against `view-catalog.snapshot.json`, so a
/// rename on the backend turns the suite red rather than showing a
/// placeholder.
///
/// **Nothing here computes.** A table is where the numbers rule is most
/// tempting and this one does not sort its rows, total a column or work out
/// a holding period: `by_term` already carries the split, `realized` already
/// carries the total, the order the lots arrive in is the `lot_method`
/// option's answer (N-2, N-10), and a duration would need the clock N-13
/// forbids. [ViewPayload.geometry] is never called — a table has no canvas,
/// so the one exemption to the numbers rule (ADR-L D-14) is not used at all.
class TaxLotsTableComponent extends ViewComponent {
  /// Creates the component.
  const TaxLotsTableComponent();

  @override
  String get viewId => 'taxlots.table.v1';

  @override
  String get a2uiComponent => 'TaxLotTable';

  @override
  Widget build(BuildContext context, ViewPayload payload) =>
      TaxLotsTableCard(data: read(payload));

  @override
  Widget skeleton(BuildContext context) => const TaxLotsTableSkeleton();

  /// Reads [payload] into the model the card draws.
  ///
  /// Exposed so the binding can be asserted without a widget tree, and so the
  /// card can be pumped from a literal in a golden test.
  TaxLotsTableData read(ViewPayload payload) {
    final splits = <TaxLotTermSplit>[
      for (final (index, half) in payload.rows('by_term').indexed)
        TaxLotTermSplit(
          term: _termOf(half.text('term'), 'by_term[$index].term'),
          label: half.text('label'),
          realizedDisplay: half.text('realized.display'),
        ),
    ];
    return TaxLotsTableData(
      title: payload.text('title'),
      subtitle: payload.text('subtitle'),
      realizedLabel: payload.text('realized.label'),
      realizedDisplay: payload.text('realized.amount.display'),
      costBasisLabel: payload.text('cost_basis.label'),
      proceedsLabel: payload.text('proceeds.label'),
      splits: splits,
      lots: <TaxLot>[
        for (final (index, lot) in payload.rows('lots').indexed)
          _lot(lot, index, splits),
      ],
    );
  }

  TaxLot _lot(ViewPayload lot, int index, List<TaxLotTermSplit> splits) {
    final term = _termOf(lot.text('term'), 'lots[$index].term');
    return TaxLot(
      label: lot.text('label'),
      acquiredOnDisplay: lot.text('acquired_on_display'),
      unitsDisplay: lot.text('units_display'),
      costBasisDisplay: lot.text('cost_basis.display'),
      proceedsDisplay: lot.text('proceeds.display'),
      gainLossDisplay: lot.text('gain_loss.display'),
      term: term,
      termLabel: _labelFor(term, index, splits),
      trend: _trendOf(lot, index),
      // The contract publishes this as a flag with `state: variant`, which
      // is what the kit's ticked, tinted row draws. Reading it is a
      // binding, not a decision (spec `frontend/0027` OD-3).
      fullySold: lot.flag('fully_sold'),
    );
  }

  /// The human label for [term], taken from the `by_term` half that shares it
  /// rather than from a constant in this file.
  ///
  /// This is a **join between two server-supplied values**, not a derived
  /// field (N-3): every string the user reads is still one the backend wrote,
  /// so it follows the `locale` option for free, where a Dart map of
  /// `{'long': 'Long-term'}` would be client-authored copy that ignores it. A
  /// term with no matching half is a payload contradicting itself, so it
  /// raises and names what is missing.
  String _labelFor(TaxLotTerm term, int index, List<TaxLotTermSplit> splits) {
    for (final split in splits) {
      if (split.term == term) return split.label;
    }
    throw PayloadContractException(
      ContractFailure(
        'by_term[].label',
        'a half whose term is "${term.name}", for lots[$index]',
      ),
    );
  }

  /// Maps the backend's `term` enum.
  ///
  /// A third spelling is a contract violation rather than a guess — the shape
  /// the waterfall's `direction` established.
  TaxLotTerm _termOf(String raw, String path) => switch (raw) {
    'short' => TaxLotTerm.short,
    'long' => TaxLotTerm.long,
    _ => throw PayloadContractException(
      ContractFailure(path, 'either "short" or "long"'),
    ),
  };

  /// Maps the backend's `trend` enum — the only source of a gain/loss colour.
  ///
  /// The sign is baked into `"+$8,925.00"` and is never read back out of it:
  /// choosing a colour by inspecting a display string is the client deriving
  /// a fact the backend already stated.
  TaxLotTrend _trendOf(ViewPayload lot, int index) =>
      switch (lot.text('trend')) {
        'up' => TaxLotTrend.up,
        'down' => TaxLotTrend.down,
        _ => throw PayloadContractException(
          ContractFailure('lots[$index].trend', 'either "up" or "down"'),
        ),
      };
}

/// Adds this component to [registry].
///
/// Called only from the generated `component_manifest.g.dart`. Every
/// component module exposes exactly one `register`, which is what
/// `binding_rules_test.dart` checks.
void register(ComponentRegistry registry) =>
    registry.register(const TaxLotsTableComponent());
