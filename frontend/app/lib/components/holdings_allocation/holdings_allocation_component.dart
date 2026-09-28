import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/holdings_allocation/allocation_gain.dart';
import 'package:finance_app/components/holdings_allocation/allocation_group.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_card.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_skeleton.dart';
import 'package:finance_app/components/surface_edits.dart';
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

  /// The declared option the toggle edits.
  ///
  /// Named once here and asserted against the catalog's `options_schema` by
  /// the contract test, so the client and the projection cannot drift.
  static const String groupOption = 'group_by';

  @override
  String get viewId => 'holdings.allocation.v1';

  @override
  String get a2uiComponent => 'HoldingsSummary';

  @override
  Widget build(BuildContext context, ViewPayload payload) {
    // Live inside a host that can re-request; read-only anywhere else, the
    // shape `order_ticket_v2` uses for the same seam (GGU-113).
    final edits = SurfaceEdits.maybeOf(context);
    return HoldingsAllocationCard(
      data: read(payload),
      onGroupChanged: edits == null
          ? null
          : (value) => edits.onOptionChanged(groupOption, value),
      isBusy: edits?.pendingOption == groupOption,
    );
  }

  @override
  Widget skeleton(BuildContext context) => const HoldingsAllocationSkeleton();

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
      // The toggle's segments, read whole: the words and which one is lit
      // are both the backend's (N-1, N-2).
      groups: <AllocationGroup>[
        for (final row in payload.rows('groups'))
          AllocationGroup(
            value: row.text('value'),
            label: row.text('label'),
            selected: row.flag('selected'),
          ),
      ],
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
