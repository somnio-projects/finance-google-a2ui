import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_card.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:finance_app/components/view_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/widgets.dart';

/// Binds `holdings.allocation.v1` — allocation by holding.
///
/// Field paths come from the backend's generated catalog entry, and
/// `app/test/architecture/catalog_contract_test.dart` checks this class's
/// [viewId] and [a2uiComponent] against `view-catalog.snapshot.json` so a
/// rename on the backend turns the suite red rather than showing a
/// placeholder on screen.
///
/// Every figure drawn is a `*.display` string. The raw `weight.value` is read
/// **only** through [ViewPayload.geometry], and only to sweep an arc — the use
/// ADR-K reserves it for (N-4). `total.amount.amount` and
/// `categories[].value.amount` stay unread: the ring is swept from the
/// weights, and a second raw member read for nothing would widen the D-14
/// seam for no gain.
class HoldingsAllocationComponent extends ViewComponent {
  /// Creates the component.
  const HoldingsAllocationComponent();

  @override
  String get viewId => 'holdings.allocation.v1';

  @override
  String get a2uiComponent => 'AllocationSummary';

  @override
  Widget build(BuildContext context, ViewPayload payload) =>
      HoldingsAllocationCard(data: read(payload));

  /// Reads [payload] into the model the card draws.
  ///
  /// Exposed so the binding can be asserted without a widget tree, and so the
  /// card can be pumped from a literal in a golden test.
  AllocationData read(ViewPayload payload) => AllocationData(
    title: payload.text('title'),
    totalLabel: payload.text('total.label'),
    totalDisplay: payload.text('total.amount.display'),
    // Rows are rendered in the order the backend sent them. Sorting is an
    // option the server owns (`sort`), never client behaviour (N-10).
    categories: <AllocationCategory>[
      for (final row in payload.rows('categories'))
        AllocationCategory(
          key: row.text('key'),
          label: row.text('label'),
          valueDisplay: row.text('value.display'),
          weightDisplay: row.text('weight.display'),
          weight: row.geometry('weight.value'),
        ),
    ],
  );
}

/// Adds this component to [registry].
///
/// Called only from the generated `component_manifest.g.dart`. Every component
/// module exposes exactly one `register`, which is what
/// `test/architecture/layering_test.dart` checks and what makes discovery
/// unambiguous.
void register(ComponentRegistry registry) =>
    registry.register(const HoldingsAllocationComponent());
