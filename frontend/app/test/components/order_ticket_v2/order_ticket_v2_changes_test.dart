import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_changes.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'order_ticket_v2_harness.dart';

void main() {
  group('changedKeys', () {
    test('marks nothing on a first render', () {
      // AC-5: everything is new, and marking all of it would say nothing.
      expect(changedKeys(null, readTicketV2(ticketV2Example())), isEmpty);
    });

    test('marks nothing when the backend returned the same strings', () {
      final before = readTicketV2(ticketV2Example());
      final after = readTicketV2(ticketV2Example());
      expect(changedKeys(before, after), isEmpty);
    });

    test('marks only the figure whose display string changed', () {
      // The comparison is on the **strings the backend sent**. No
      // subtraction, no threshold, no sign.
      final before = readTicketV2(ticketV2Example());
      final after = readTicketV2(ticketV2ExampleWithTotal(r'$99,000.00'));
      expect(changedKeys(before, after), equals(<String>{'total'}));
    });

    test('marks a stepped leg by its slots, and names it as stepped', () {
      final before = readTicketV2(ticketV2Example());
      final after = readTicketV2(ticketV2ExampleStepped());
      final key = after.lines.first.key;
      final changed = changedKeys(before, after);

      expect(
        changed,
        equals(<String>{LineSlots.quantity(key), LineSlots.notional(key)}),
      );
      expect(steppedLegs(changed, after), equals(<String>{key}));
      expect(steppedLegs(const <String>{}, after), isEmpty);
    });

    test('marks a weight row by its after figure', () {
      final before = readTicketV2(ticketV2Example());
      final example = <String, dynamic>{...ticketV2Example()};
      final impact = <String, dynamic>{
        ...example['impact']! as Map<String, dynamic>,
      };
      final shifts = (impact['weight_shifts']! as List<dynamic>)
          .cast<Map<String, dynamic>>();
      impact['weight_shifts'] = <Map<String, dynamic>>[
        <String, dynamic>{
          ...shifts.first,
          'after': <String, dynamic>{'value': '0.5', 'display': '50.00%'},
        },
        ...shifts.skip(1),
      ];
      example['impact'] = impact;
      final after = readTicketV2(example);

      expect(
        changedKeys(before, after),
        equals(<String>{LineSlots.shift(after.shifts.first.key)}),
      );
    });

    test('ignores a slot the previous render did not carry', () {
      final before = readTicketV2(ticketV2Example());
      final current = OrderTicketV2Data(
        title: before.title,
        badge: before.badge,
        side: before.side,
        legs: before.legs,
        lines: before.lines,
        figures: const <OrderTicketV2Figure>[
          OrderTicketV2Figure(name: 'invented', label: 'X', display: 'Y'),
        ],
        shifts: before.shifts,
        controls: before.controls,
        breach: before.breach,
        message: before.message,
        disclosure: before.disclosure,
      );
      expect(changedKeys(before, current), isEmpty);
    });
  });

  group(OrderTicketV2Data, () {
    test('is blocked exactly when the backend declared a breach', () {
      expect(readTicketV2(ticketV2Example()).isBlocked, isFalse);
      expect(readTicketV2(ticketV2ExampleBlocked()).isBlocked, isTrue);
    });

    test('compares by value', () {
      expect(
        readTicketV2(ticketV2Example()),
        equals(readTicketV2(ticketV2Example())),
      );
      expect(
        readTicketV2(ticketV2Example()),
        isNot(equals(readTicketV2(ticketV2ExampleBlocked()))),
      );
      final line = readTicketV2(ticketV2Example()).lines.first;
      expect(line.props, contains(line.increment));
      final shift = readTicketV2(ticketV2Example()).shifts.first;
      expect(shift.props, contains(shift.afterDisplay));
    });
  });
}
