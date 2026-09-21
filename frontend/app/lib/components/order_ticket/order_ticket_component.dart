import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/order_ticket/order_ticket_card.dart';
import 'package:finance_app/components/order_ticket/order_ticket_model.dart';
import 'package:finance_app/components/view_component.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/widgets.dart';

/// Binds `order.ticket.v1` — a proposed order, and the options that re-render
/// it.
///
/// This is the catalog's only interactive component, and the one place where
/// the product's central claim is either demonstrated or broken. It is
/// demonstrated here by omission: **there is no arithmetic in this file.**
/// Every figure is a `*.display` string the backend formatted, and the raw
/// `quantity.units`, `entry_price.amount` and `notional.amount.amount`
/// members are read by nothing — this component draws no chart, so it has no
/// legitimate use for a raw decimal at all (N-4).
///
/// An edit is not an event this component handles. It re-requests the same
/// view with the changed option (ADR-K D-11), which is the host's job: the
/// card exposes a callback and [build] passes none, exactly as
/// `AttributionWaterfallCard` does with `onSegmentTap`. Without a host that
/// can re-request, the ticket renders read-only rather than offering a
/// control it cannot honour (spec 0006 AC-10).
class OrderTicketComponent extends ViewComponent {
  /// Creates the component.
  const OrderTicketComponent();

  /// The caption the app puts beside the unit count.
  ///
  /// The contract gives `notional` a server-written `label` and gives
  /// `quantity` and `entry_price` none, so these two are the app's own
  /// chrome — the same category as the `Portfolio` in the app bar, not a
  /// figure and not a compliance statement. Anything the backend does write
  /// is rendered verbatim instead.
  static const String unitsLabel = 'Units';

  /// The caption the app puts beside the unit price. See [unitsLabel].
  static const String entryPriceLabel = 'Entry price';

  @override
  String get viewId => 'order.ticket.v1';

  @override
  String get a2uiComponent => 'OrderTicket';

  @override
  Widget build(BuildContext context, ViewPayload payload) =>
      OrderTicketCard(data: read(payload));

  /// Reads [payload] into the model the card renders.
  ///
  /// Exposed so the binding can be asserted without a widget tree, and so a
  /// host can build the card itself with a callback attached.
  OrderTicketData read(ViewPayload payload) {
    return OrderTicketData(
      title: payload.text('title'),
      symbol: payload.text('symbol'),
      name: payload.text('name'),
      side: payload.text('side'),
      figures: <OrderTicketFigure>[
        OrderTicketFigure(
          name: 'quantity',
          label: unitsLabel,
          display: payload.text('quantity.display'),
        ),
        OrderTicketFigure(
          name: 'entry_price',
          label: entryPriceLabel,
          display: payload.text('entry_price.display'),
        ),
        OrderTicketFigure(
          name: 'notional',
          label: payload.text('notional.label'),
          display: payload.text('notional.amount.display'),
        ),
      ],
      fields: _fields(payload),
      disclosure: payload.text('disclosure'),
    );
  }

  /// Reads the editable options the payload declares, in arrival order.
  ///
  /// **Nothing here names an option.** The set comes from `inputs[]`, which
  /// the backend builds from its own options model's JSON schema, so the
  /// fields a person may edit and the options the endpoint accepts cannot
  /// disagree. A hardcoded list here would be a second declaration of one
  /// fact, which is the defect this whole contract is shaped to avoid
  /// (spec 0006 AC-2).
  List<OrderTicketField> _fields(ViewPayload payload) {
    final inputs = payload.rows('inputs');
    return <OrderTicketField>[
      for (final (index, input) in inputs.indexed)
        OrderTicketField(
          option: input.text('option'),
          label: input.text('label'),
          control: _controlOf(input, index),
          value: input.text('value'),
          choices: input.strings('choices'),
          pattern: input.optionalText('pattern'),
        ),
    ];
  }

  /// Maps the contract's `control` enum onto this app's.
  ///
  /// An undeclared spelling raises rather than defaulting: the contract says
  /// `choice / text`, so a third value means the payload and this build
  /// disagree, and rendering a text field for something the backend meant as
  /// a closed list would invent a bound nobody declared (N-3, N-8).
  OrderTicketControl _controlOf(ViewPayload input, int index) => switch (input
      .text('control')) {
    'choice' => OrderTicketControl.choice,
    'text' => OrderTicketControl.text,
    _ => throw PayloadContractException(
      ContractFailure('inputs[$index].control', 'either "choice" or "text"'),
    ),
  };
}

/// Adds this component to [registry].
///
/// Called only from the generated `component_manifest.g.dart`. Every
/// component module exposes exactly one `register`, which is what
/// `binding_rules_test.dart` checks.
void register(ComponentRegistry registry) =>
    registry.register(const OrderTicketComponent());
