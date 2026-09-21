import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_card.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:finance_app/components/view_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/widgets.dart';

/// Binds `holdings.allocation.v1` — the allocation donut, grouped as asked.
///
/// Field paths come from the backend's generated catalog entry, and
/// `app/test/architecture/catalog_contract_test.dart` checks this class's
/// [viewId] and [a2uiComponent] against `view-catalog.snapshot.json` so a
/// rename on the backend turns the suite red rather than showing a
/// placeholder on screen.
///
/// Every figure drawn is a `*.display` string. The raw `weight.value` is read
/// **only** through [ViewPayload.geometry], and only to sweep an arc and size
/// a bar — the use ADR-K reserves it for (N-4). `total.amount.amount` and
/// `categories[].value.amount` stay unread.
class HoldingsAllocationComponent extends ViewComponent {
  /// Creates the component.
  const HoldingsAllocationComponent();

  @override
  String get viewId => 'holdings.allocation.v1';

  @override
  String get a2uiComponent => 'HoldingsSummary';

  @override
  Widget build(BuildContext context, ViewPayload payload) =>
      HoldingsAllocationCard(data: read(payload));

  /// Reads [payload] into the model the card draws.
  ///
  /// Exposed so the binding can be asserted without a widget tree, and so the
  /// card can be pumped from a literal in a golden test. `total_gain` is the
  /// one optional block: the backend omits it when `headline=false`, and its
  /// absence is what tells the card a shell is drawing the title (spec 0026).
  AllocationData read(ViewPayload payload) {
    final gainPeriod = payload.optionalText('total_gain.period');
    return AllocationData(
      title: payload.text('title'),
      totalLabel: payload.text('total.label'),
      totalDisplay: payload.text('total.amount.display'),
      groupBy: payload.text('group_by'),
      centerCount: payload.text('center.count'),
      centerUnit: payload.text('center.unit'),
      headline: gainPeriod != null,
      totalGain: gainPeriod == null
          ? null
          : AllocationGain(
              amountDisplay: payload.text('total_gain.amount.display'),
              percentDisplay: payload.text('total_gain.percent.display'),
              trend: payload.text('total_gain.trend'),
              period: gainPeriod,
            ),
      // Rows are rendered in the order the backend sent them (N-10).
      categories: <AllocationCategory>[
        for (final row in payload.rows('categories'))
          AllocationCategory(
            key: row.text('key'),
            label: row.text('label'),
            valueDisplay: row.text('value.display'),
            weightDisplay: row.text('weight.display'),
            weight: row.geometry('weight.value'),
            changeDisplay: row.text('change.display'),
            trend: row.text('trend'),
          ),
      ],
    );
  }
}

/// Adds this component to [registry].
///
/// Called only from the generated `component_manifest.g.dart`. Every component
/// module exposes exactly one `register`, which is what
/// `test/architecture/layering_test.dart` checks and what makes discovery
/// unambiguous.
void register(ComponentRegistry registry) =>
    registry.register(const HoldingsAllocationComponent());
