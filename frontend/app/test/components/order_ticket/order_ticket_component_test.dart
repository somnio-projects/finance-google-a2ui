import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/order_ticket/order_ticket_card.dart';
import 'package:finance_app/components/order_ticket/order_ticket_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'order_ticket_harness.dart';

void main() {
  group(OrderTicketComponent, () {
    const component = OrderTicketComponent();

    // A Scaffold, because that is what hosts the component in both real
    // surfaces and its form controls need a Material ancestor.
    Widget subject() => Scaffold(
      body: SingleChildScrollView(
        child: Builder(
          builder: (context) => component.build(context, orderTicketPayload()),
        ),
      ),
    );

    testWidgets('binds every display string verbatim', (tester) async {
      // AC-3 / N-1: the figures on screen are exactly the `*.display`
      // strings the backend sent. Read from the catalog, not typed here.
      final example = orderTicketExample();
      final quantity = example['quantity']! as Map<String, dynamic>;
      final price = example['entry_price']! as Map<String, dynamic>;
      final notional = example['notional']! as Map<String, dynamic>;
      final amount = notional['amount']! as Map<String, dynamic>;
      await tester.pumpApp(subject());

      expect(find.text(example['title']! as String), findsOneWidget);
      expect(find.text(quantity['display']! as String), findsWidgets);
      expect(find.text(price['display']! as String), findsWidgets);
      expect(find.text(notional['label']! as String), findsOneWidget);
      expect(find.text(amount['display']! as String), findsWidgets);
    });

    testWidgets('never puts a raw figure on screen', (tester) async {
      // N-4. This component draws no chart, so it has no legitimate use for
      // a raw decimal at all — `geometry` is never called.
      final example = orderTicketExample();
      final price = example['entry_price']! as Map<String, dynamic>;
      final notional = example['notional']! as Map<String, dynamic>;
      final amount = notional['amount']! as Map<String, dynamic>;
      await tester.pumpApp(subject());

      expect(find.text(price['amount']! as String), findsNothing);
      expect(find.text(amount['amount']! as String), findsNothing);
    });

    testWidgets('renders the disclosure verbatim', (tester) async {
      // AC-11 / N-9: a compliance statement is never trimmed or reworded.
      await tester.pumpApp(subject());
      expect(
        find.text(orderTicketExample()['disclosure']! as String),
        findsOneWidget,
      );
    });

    testWidgets('renders read-only without a host that can re-request', (
      tester,
    ) async {
      // AC-10. `build` attaches no callback, so every control is disabled
      // rather than pretending an edit would do something.
      await tester.pumpApp(subject());
      final card = tester.widget<OrderTicketCard>(find.byType(OrderTicketCard));
      expect(card.onOptionChanged, isNull);

      final fields = tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      );
      expect(fields, isNotEmpty);
      for (final field in fields) {
        expect(field.enabled, isFalse);
      }
    });

    testWidgets('raises a missing field instead of reconstructing it', (
      tester,
    ) async {
      // N-3: the payload is missing a field — it is not this component's job
      // to invent one.
      final incomplete = ViewPayload.fromJson(
        orderTicketExampleWithout('notional'),
      );
      await tester.pumpApp(
        Builder(builder: (context) => component.build(context, incomplete)),
      );
      expect(tester.takeException(), isA<PayloadContractException>());
    });

    testWidgets('raises on a control spelling the contract does not declare', (
      tester,
    ) async {
      final example = orderTicketExample();
      final inputs = (example['inputs']! as List<dynamic>)
          .cast<Map<String, dynamic>>();
      example['inputs'] = <Map<String, dynamic>>[
        <String, dynamic>{...inputs.first, 'control': 'slider'},
        ...inputs.skip(1),
      ];
      await tester.pumpApp(
        Builder(
          builder: (context) =>
              component.build(context, ViewPayload.fromJson(example)),
        ),
      );
      final error = tester.takeException();
      expect(error, isA<PayloadContractException>());
      expect(
        (error as PayloadContractException).failure.message,
        contains('inputs[0].control'),
      );
    });

    group('register', () {
      test('adds exactly this component to a registry', () {
        final registry = ComponentRegistry();
        register(registry);
        expect(registry.lookup('order.ticket.v1'), isA<OrderTicketComponent>());
        expect(registry.viewIds, hasLength(1));
      });
    });
  });
}
