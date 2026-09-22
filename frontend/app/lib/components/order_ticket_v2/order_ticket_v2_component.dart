import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_card.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_model.dart';
import 'package:finance_app/components/view_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/widgets.dart';

/// Binds `order.ticket.v2` — the multi-leg draft order with its live impact.
///
/// Flow C's surface as the design draws it, and the second interactive
/// component in the catalog. Like `order.ticket.v1` it demonstrates the
/// product's claim by omission: **there is no arithmetic in this file**. The
/// stepper is the sharpest case — a `+` cannot add one to `3`, so every leg
/// carries the whole `legs` value its `+` and `-` send, written by the
/// backend, and the card sends that string back unchanged (spec
/// frontend/0013 AC-2). The one raw member read, `weight.value`, goes through
/// [ViewPayload.geometry] and only sizes a bar (N-4, ADR-L D-14).
///
/// An edit is the host's to make: the card exposes a callback and [build]
/// passes none, so without a host that can re-request the view the ticket
/// renders read-only rather than offering a control it cannot honour (spec
/// frontend/0006 AC-10, reused).
class OrderTicketV2Component extends ViewComponent {
  /// Creates the component.
  const OrderTicketV2Component();

  /// The one option an edit sends. It is also the payload field carrying the
  /// value in effect — that naming *is* the interactivity declaration
  /// (`.claude/rules/backend/presentation.md` §4), and
  /// `order_ticket_v2_contract_test.dart` checks it against the catalog.
  static const String legsOption = 'legs';

  @override
  String get viewId => 'order.ticket.v2';

  @override
  String get a2uiComponent => 'MultiLegOrderTicket';

  @override
  Widget build(BuildContext context, ViewPayload payload) =>
      OrderTicketV2Card(data: read(payload));

  /// Reads [payload] into the model the card renders.
  ///
  /// Exposed so the binding can be asserted without a widget tree, and so a
  /// host can build the card itself with a callback attached.
  OrderTicketV2Data read(ViewPayload payload) => OrderTicketV2Data(
    title: payload.text('title'),
    badge: payload.text('badge'),
    side: payload.text('side'),
    // The literal, not [legsOption]: a reader argument is always a literal
    // (N-5); the contract test asserts the two spell one name.
    legs: payload.text('legs'),
    // Rows are rendered in the order the backend sent them (N-10).
    lines: <OrderTicketV2Line>[
      for (final row in payload.rows('lines')) _line(row),
    ],
    figures: <OrderTicketV2Figure>[
      OrderTicketV2Figure(
        name: 'total',
        label: payload.text('impact.total.label'),
        display: payload.text('impact.total.amount.display'),
      ),
      OrderTicketV2Figure(
        name: 'units',
        label: payload.text('impact.units.label'),
        display: payload.text('impact.units.units.display'),
      ),
      OrderTicketV2Figure(
        name: 'fees',
        label: payload.text('impact.fees.label'),
        display: payload.text('impact.fees.amount.display'),
      ),
      OrderTicketV2Figure(
        name: 'cash',
        label: payload.text('impact.cash_remaining.label'),
        display: payload.text('impact.cash_remaining.amount.display'),
      ),
    ],
    shifts: <OrderTicketV2Shift>[
      for (final row in payload.rows('impact.weight_shifts'))
        OrderTicketV2Shift(
          key: row.text('key'),
          label: row.text('label'),
          beforeDisplay: row.text('before.display'),
          afterDisplay: row.text('after.display'),
        ),
    ],
    breach: payload.text('constraints.breach'),
    message: payload.optionalText('constraints.message'),
    disclosure: payload.text('disclosure'),
  );

  /// Reads one `lines[]` entry.
  OrderTicketV2Line _line(ViewPayload row) => OrderTicketV2Line(
    key: row.text('key'),
    symbol: row.text('symbol'),
    name: row.text('name'),
    priceDisplay: row.text('price.display'),
    quantityDisplay: row.text('quantity.display'),
    notionalDisplay: row.text('notional.display'),
    weightDisplay: row.text('weight.display'),
    weight: row.geometry('weight.value'),
    increment: row.optionalText('increment'),
    decrement: row.optionalText('decrement'),
  );
}

/// Adds this component to [registry].
///
/// Called only from the generated `component_manifest.g.dart`. Every
/// component module exposes exactly one `register`, which is what
/// `binding_rules_test.dart` checks.
void register(ComponentRegistry registry) =>
    registry.register(const OrderTicketV2Component());
