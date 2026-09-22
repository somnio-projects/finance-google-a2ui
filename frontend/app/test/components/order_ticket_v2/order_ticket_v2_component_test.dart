import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_card.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'order_ticket_v2_harness.dart';

void main() {
  group(OrderTicketV2Component, () {
    const component = OrderTicketV2Component();

    Widget subject() => Scaffold(
      body: SingleChildScrollView(
        child: Builder(
          builder: (context) => component.build(context, ticketV2Payload()),
        ),
      ),
    );

    testWidgets('binds every display string verbatim', (tester) async {
      // AC-1 / N-1: what is on screen is exactly what the backend sent, read
      // from the catalog rather than typed here.
      final example = ticketV2Example();
      final lines = (example['lines']! as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final impact = example['impact']! as Map<String, dynamic>;
      final total = impact['total']! as Map<String, dynamic>;
      final amount = total['amount']! as Map<String, dynamic>;
      await tester.pumpApp(subject(), surfaceSize: const Size(800, 1600));

      for (final line in lines) {
        final notional = line['notional']! as Map<String, dynamic>;
        final quantity = line['quantity']! as Map<String, dynamic>;
        expect(find.text(line['symbol']! as String), findsOneWidget);
        expect(find.text(notional['display']! as String), findsOneWidget);
        expect(find.text(quantity['display']! as String), findsOneWidget);
      }
      expect(find.text(total['label']! as String), findsOneWidget);
      expect(find.text(amount['display']! as String), findsOneWidget);
    });

    testWidgets('never puts a raw figure on screen', (tester) async {
      // N-4. The one raw member read, `weight.value`, sizes a bar.
      final example = ticketV2Example();
      final lines = (example['lines']! as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final weight = lines.first['weight']! as Map<String, dynamic>;
      final price = lines.first['price']! as Map<String, dynamic>;
      await tester.pumpApp(subject(), surfaceSize: const Size(800, 1600));

      expect(find.text(weight['value']! as String), findsNothing);
      expect(find.text(price['amount']! as String), findsNothing);
    });

    testWidgets('renders the disclosure verbatim', (tester) async {
      // N-9: a compliance statement is never trimmed or reworded.
      await tester.pumpApp(subject(), surfaceSize: const Size(800, 1600));
      expect(
        find.text(ticketV2Example()['disclosure']! as String),
        findsOneWidget,
      );
    });

    testWidgets('renders read-only without a host that can re-request', (
      tester,
    ) async {
      // AC-4. `build` attaches no callback, so every stepper is disabled
      // rather than pretending a tap would do something.
      await tester.pumpApp(subject(), surfaceSize: const Size(800, 1600));
      final card = tester.widget<OrderTicketV2Card>(
        find.byType(OrderTicketV2Card),
      );
      expect(card.onLegsChanged, isNull);
      final taps = tester.widgetList<InkWell>(find.byType(InkWell));
      expect(taps, isNotEmpty);
      for (final tap in taps) {
        expect(tap.onTap, isNull);
      }
    });

    testWidgets('raises a missing field instead of reconstructing it', (
      tester,
    ) async {
      // N-3: the payload is missing a field — not this component's to invent.
      final incomplete = ViewPayload.fromJson(
        ticketV2ExampleWithout('constraints'),
      );
      await tester.pumpApp(
        Builder(builder: (context) => component.build(context, incomplete)),
      );
      expect(tester.takeException(), isA<PayloadContractException>());
    });

    test('reads the stepper values the backend wrote, or their absence', () {
      final data = component.read(ticketV2Payload());
      final lines = (ticketV2Example()['lines']! as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (final (index, line) in data.lines.indexed) {
        expect(line.increment, lines[index]['increment']);
        expect(line.decrement, lines[index]['decrement']);
      }
      final zero = <String, dynamic>{...lines.first, 'decrement': null};
      final example = <String, dynamic>{...ticketV2Example()};
      example['lines'] = <Map<String, dynamic>>[zero, ...lines.skip(1)];
      expect(readTicketV2(example).lines.first.decrement, isNull);
    });

    group('register', () {
      test('adds exactly this component to a registry', () {
        final registry = ComponentRegistry();
        register(registry);
        expect(
          registry.lookup('order.ticket.v2'),
          isA<OrderTicketV2Component>(),
        );
        expect(registry.viewIds, hasLength(1));
      });
    });
  });
}
