import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_card.dart';
import 'package:finance_app/components/view_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/widgets.dart';

/// Binds `holdings.allocation.v1` — allocation by holding.
///
/// Field paths come from the backend's frozen catalog entry for this view; the
/// component reads them and prints them. Every figure on screen is a
/// `*.display` string, and the raw `*.amount` / `*.value` members are read by
/// nothing here (N-4) — they exist for chart geometry, which this skeleton
/// does not draw yet.
class HoldingsAllocationComponent extends ViewComponent {
  /// Creates the component.
  const HoldingsAllocationComponent();

  @override
  String get viewId => 'holdings.allocation.v1';

  @override
  String get a2uiComponent => 'DonutChart';

  @override
  Widget build(BuildContext context, ViewPayload payload) {
    return HoldingsAllocationCard(
      title: payload.text('title'),
      totalLabel: payload.text('total.label'),
      totalDisplay: payload.text('total.amount.display'),
      // Rows are rendered in the order the backend sent them. Sorting is an
      // option the server owns (`sort`), never client behaviour (N-10).
      categories: <HoldingsAllocationRow>[
        for (final row in payload.rows('categories'))
          HoldingsAllocationRow(
            categoryKey: row.text('key'),
            label: row.text('label'),
            valueDisplay: row.text('value.display'),
            weightDisplay: row.text('weight.display'),
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
