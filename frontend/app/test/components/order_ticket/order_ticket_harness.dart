import 'package:finance_app/components/order_ticket/order_ticket_component.dart';
import 'package:finance_app/components/order_ticket/order_ticket_model.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

import '../../helpers/catalog_snapshot.dart';

/// The A2UI component name the backend's catalog serves this view under.
const String orderTicketComponent = 'OrderTicket';

/// The catalog entry for the order ticket, read from the generated snapshot.
///
/// Read, never copied: `docs/catalog/view-catalog.snapshot.json` is the
/// backend's generated contract, and a checked-in Dart copy of it is the
/// second source that goes stale
/// (`.claude/rules/frontend/testing.md` §5).
Map<String, dynamic> orderTicketEntry() =>
    CatalogSnapshot.load().entryFor(orderTicketComponent);

/// The view id the **backend's catalog** publishes for this component.
///
/// Read from the snapshot rather than from any constant in `lib/`, so a
/// test envelope is keyed by the contract and not by the same literal the
/// code under test uses — otherwise a typo would agree with itself.
String orderTicketViewId() =>
    CatalogSnapshot.load().viewIdFor(orderTicketComponent);

/// The contract's own example payload for the order ticket.
Map<String, dynamic> orderTicketExample() =>
    CatalogSnapshot.load().exampleFor(orderTicketComponent);

/// The example, as the payload a component binds.
ViewPayload orderTicketPayload() =>
    ViewPayload.fromJson(<String, dynamic>{...orderTicketExample()});

/// Reads [json] through the component under test, so every suite binds the
/// payload the same way rather than each building its own model.
OrderTicketData readOrderTicket(Map<String, dynamic> json) =>
    const OrderTicketComponent().read(ViewPayload.fromJson(json));

/// The declared option names of `order.ticket.v1`, from `options_schema`.
///
/// This is the **authority on editability**: a payload field is editable
/// exactly when an option of this name exists (spec 0006 AC-2).
Set<String> declaredOptionNames() {
  final schema = orderTicketEntry()['options_schema']! as Map<String, dynamic>;
  final properties = schema['properties']! as Map<String, dynamic>;
  return properties.keys.toSet();
}

/// The schema of one declared option, e.g. `side`.
Map<String, dynamic> optionSchema(String option) {
  final schema = orderTicketEntry()['options_schema']! as Map<String, dynamic>;
  final properties = schema['properties']! as Map<String, dynamic>;
  return properties[option]! as Map<String, dynamic>;
}

/// The example payload with [path] removed, for the missing-field path.
Map<String, dynamic> orderTicketExampleWithout(String path) {
  final example = <String, dynamic>{...orderTicketExample()}..remove(path);
  return example;
}

/// The example payload with one figure's display string replaced.
///
/// Used to prove that a *changed* figure is marked — by changing what the
/// backend said, never by computing a new value here.
Map<String, dynamic> orderTicketExampleWithNotional(String display) {
  final example = <String, dynamic>{...orderTicketExample()};
  final notional = <String, dynamic>{
    ...example['notional']! as Map<String, dynamic>,
  };
  final amount = <String, dynamic>{
    ...notional['amount']! as Map<String, dynamic>,
  };
  amount['display'] = display;
  notional['amount'] = amount;
  example['notional'] = notional;
  return example;
}
