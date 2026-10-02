import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_component.dart';
import 'package:flutter_test/flutter_test.dart';

import 'order_ticket_v2_harness.dart';

/// The interactivity claim, asserted against the backend's generated catalog.
///
/// `order.ticket.v2` publishes no `inputs[]`: its editability is declared by
/// **naming** — the `legs` option is a payload field of exactly that name
/// (`.claude/rules/backend/presentation.md` §4) — and its controls are the
/// stepper values the backend wrote. Both halves are read from
/// `docs/catalog/view-catalog.snapshot.json`, never typed here.
void main() {
  group('order.ticket.v2 interactivity contract', () {
    const component = OrderTicketV2Component();

    test('serves the frozen view id and the catalog component name', () {
      expect(component.viewId, equals('order.ticket.v2'));
      expect(component.a2uiComponent, equals(multiLegComponent));
      expect(ticketV2ViewId(), equals(component.viewId));
    });

    test('the option an edit sends is one the schema declares', () {
      // AC-2, first half. A `legs` the options model would reject is a
      // control that cannot round-trip (ADR-K D-3).
      final schema = ticketV2Entry()['options_schema']! as Map<String, dynamic>;
      final properties = schema['properties']! as Map<String, dynamic>;
      expect(properties.keys, contains(OrderTicketV2Component.legsOption));
    });

    test('the option an edit sends is a payload field of the same name', () {
      // AC-2, second half: *that naming is the interactivity declaration*.
      // The value in effect is what the card starts from.
      final example = ticketV2Example();
      final data = component.read(ticketV2Payload());
      expect(example.keys, contains(OrderTicketV2Component.legsOption));
      expect(data.legs, equals(example[OrderTicketV2Component.legsOption]));
    });

    test('the contract marks `legs` as the field a caller sends back', () {
      final fields = (ticketV2Entry()['fields']! as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final legs = fields.singleWhere((field) => field['path'] == 'legs');
      expect(legs['input'], isNotNull);
      // And nothing under `lines[]` is: a rendered leg is an output.
      final lineFields = fields.where(
        (field) => (field['path'] as String).startsWith('lines[]'),
      );
      expect(lineFields, isNotEmpty);
      for (final field in lineFields) {
        expect(field['input'], isNull, reason: '${field['path']} round-trips?');
      }
    });

    test('every stepper value satisfies the declared bound', () {
      // AC-2: the backend wrote them from the same pattern it enforces, so
      // each is a value the options model takes back. Asserted in the test —
      // the client itself re-validates nothing (N-8).
      final pattern = RegExp(ticketV2OptionSchema('legs')['pattern'] as String);
      final data = component.read(ticketV2Payload());
      expect(data.lines, isNotEmpty);
      for (final line in data.lines) {
        for (final value in <String?>[line.increment, line.decrement]) {
          expect(value, isNotNull);
          expect(pattern.hasMatch(value!), isTrue, reason: value);
        }
      }
    });

    test('the blocked state is a declared field, not a comparison', () {
      // The client reads `breach`; it never subtracts cash from a total.
      final schema = ticketV2Entry()['fields']! as List<dynamic>;
      final breach = schema.cast<Map<String, dynamic>>().singleWhere(
        (field) => field['path'] == 'constraints.breach',
      );
      expect(breach['type'], contains('over_cash'));
      expect(readTicketV2(ticketV2Example()).isBlocked, isFalse);
      expect(readTicketV2(ticketV2ExampleBlocked()).isBlocked, isTrue);
    });
  });
}
