import 'package:finance_app/components/order_ticket/order_ticket_component.dart';
import 'package:finance_app/components/order_ticket/order_ticket_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'order_ticket_harness.dart';

/// The interactivity claim, asserted against the backend's generated catalog.
///
/// These are the tests that make "editability is **derived**" true rather than
/// asserted. Every expectation is read from
/// `docs/catalog/view-catalog.snapshot.json`; none of them names a field, so
/// hardcoding one in the component turns them red.
void main() {
  group('order.ticket.v1 interactivity contract', () {
    const component = OrderTicketComponent();

    test('serves the frozen view id and the catalog component name', () {
      expect(component.viewId, equals('order.ticket.v1'));
      expect(component.a2uiComponent, equals(orderTicketComponent));
    });

    test('every editable input names an option the schema declares', () {
      // AC-2, first half. A control the options model would reject is a
      // control that cannot round-trip — ADR-K D-3.
      final fields = component.read(orderTicketPayload()).fields;
      final declared = declaredOptionNames();
      expect(fields, isNotEmpty);
      for (final field in fields) {
        expect(
          declared,
          contains(field.option),
          reason:
              '"${field.option}" is offered as editable but is not a '
              "property of the view's options_schema",
        );
      }
    });

    test('every editable input names a payload field of the same name', () {
      // AC-2, second half. *That naming is the interactivity declaration*
      // (`.claude/rules/backend/presentation.md` §4): an input whose option
      // has no payload field of its own name has no current value to send
      // back, and the round trip would be guesswork.
      final example = orderTicketExample();
      final fields = component.read(orderTicketPayload()).fields;
      for (final field in fields) {
        expect(
          example.keys,
          contains(field.option),
          reason:
              '"${field.option}" is editable but the payload carries no '
              'field of that name',
        );
        expect(example[field.option], equals(field.value));
      }
    });

    test('the editable set is exactly what the payload published', () {
      // The component neither adds an input the payload did not declare nor
      // drops one it did. Both directions, because a subset would still pass
      // the two tests above.
      final inputs = (orderTicketExample()['inputs']! as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final offered = component
          .read(orderTicketPayload())
          .fields
          .map((field) => field.option)
          .toList();
      expect(offered, equals(inputs.map((i) => i['option']).toList()));
    });

    test('a choice offers exactly the values its option declares', () {
      // AC-6. The bound is the server's; the client neither narrows nor
      // widens it (N-8).
      final fields = component.read(orderTicketPayload()).fields;
      final choices = fields.where(
        (field) => field.control == OrderTicketControl.choice,
      );
      expect(choices, isNotEmpty);
      for (final field in choices) {
        expect(
          field.choices,
          equals(optionSchema(field.option)['enum']),
          reason: '"${field.option}" offers a list its schema does not',
        );
      }
    });

    test("a text control declares exactly its option's pattern", () {
      // AC-6 again, for the other control. An invented bound would show a
      // reader a rule the backend does not enforce.
      final fields = component.read(orderTicketPayload()).fields;
      final texts = fields.where(
        (field) => field.control == OrderTicketControl.text,
      );
      expect(texts, isNotEmpty);
      for (final field in texts) {
        expect(
          field.pattern,
          equals(optionSchema(field.option)['pattern']),
          reason: '"${field.option}" declares a pattern its schema does not',
        );
      }
    });

    test('an option the payload does not offer is not made editable', () {
      // `precision`, `locale` and `currency` are declared options with no
      // payload field of their own name, so they are knobs a caller may send
      // but **not** fields this ticket offers. The distinction is the whole
      // of AC-2: declared is necessary, not sufficient.
      final offered = component
          .read(orderTicketPayload())
          .fields
          .map((field) => field.option)
          .toSet();
      final notOffered = declaredOptionNames().difference(offered);
      expect(notOffered, isNotEmpty);
      for (final option in notOffered) {
        expect(orderTicketExample().keys, isNot(contains(option)));
      }
    });
  });
}
