import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_component.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_model.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

import '../../helpers/catalog_snapshot.dart';

/// The A2UI component name the backend's catalog serves this view under.
const String multiLegComponent = 'MultiLegOrderTicket';

/// The catalog entry, read from the generated snapshot — never copied
/// (`.claude/rules/frontend/testing.md` §5).
Map<String, dynamic> ticketV2Entry() =>
    CatalogSnapshot.load().entryFor(multiLegComponent);

/// The view id the **catalog** publishes, so an envelope is keyed by the
/// contract rather than by the literal the code under test uses.
String ticketV2ViewId() => CatalogSnapshot.load().viewIdFor(multiLegComponent);

/// The contract's own example payload.
Map<String, dynamic> ticketV2Example() =>
    CatalogSnapshot.load().exampleFor(multiLegComponent);

/// The example, as the payload a component binds.
ViewPayload ticketV2Payload() =>
    ViewPayload.fromJson(<String, dynamic>{...ticketV2Example()});

/// Reads [json] through the component under test.
OrderTicketV2Data readTicketV2(Map<String, dynamic> json) =>
    const OrderTicketV2Component().read(ViewPayload.fromJson(json));

/// The schema of one declared option, e.g. `legs`.
Map<String, dynamic> ticketV2OptionSchema(String option) {
  final schema = ticketV2Entry()['options_schema']! as Map<String, dynamic>;
  final properties = schema['properties']! as Map<String, dynamic>;
  return properties[option]! as Map<String, dynamic>;
}

/// The example with [path] removed, for the missing-field path.
Map<String, dynamic> ticketV2ExampleWithout(String path) =>
    <String, dynamic>{...ticketV2Example()}..remove(path);

/// The example with the panel's total replaced by [display].
///
/// Used to prove a *changed* figure is marked — by changing what the backend
/// said, never by computing a new value here.
Map<String, dynamic> ticketV2ExampleWithTotal(String display) {
  final example = <String, dynamic>{...ticketV2Example()};
  final impact = <String, dynamic>{
    ...example['impact']! as Map<String, dynamic>,
  };
  final total = <String, dynamic>{...impact['total']! as Map<String, dynamic>};
  final amount = <String, dynamic>{...total['amount']! as Map<String, dynamic>};
  amount['display'] = display;
  total['amount'] = amount;
  impact['total'] = total;
  example['impact'] = impact;
  return example;
}

/// The example with the first leg's shares and amount replaced — what the
/// backend answers after a `+` tap.
Map<String, dynamic> ticketV2ExampleStepped({
  String quantity = '4',
  String notional = r'$4,818.64',
}) {
  final example = <String, dynamic>{...ticketV2Example()};
  final lines = (example['lines']! as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final first = <String, dynamic>{...lines.first};
  first['quantity'] = <String, dynamic>{'units': quantity, 'display': quantity};
  first['notional'] = <String, dynamic>{'amount': '0', 'display': notional};
  example['lines'] = <Map<String, dynamic>>[first, ...lines.skip(1)];
  return example;
}

/// The example as the backend renders a draft over the available cash.
Map<String, dynamic> ticketV2ExampleBlocked({
  String message = r'Exceeds available cash — reduce order by $2,300.00.',
}) {
  final example = <String, dynamic>{...ticketV2Example()};
  example['badge'] = 'blocked';
  example['constraints'] = <String, dynamic>{
    ...example['constraints']! as Map<String, dynamic>,
    'breach': 'over_cash',
    'shortfall': <String, dynamic>{'amount': '2300', 'display': r'$2,300.00'},
    'message': message,
  };
  return example;
}
