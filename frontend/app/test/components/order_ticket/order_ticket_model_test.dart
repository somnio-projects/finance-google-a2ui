import 'package:finance_app/components/order_ticket/order_ticket_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'order_ticket_harness.dart';

/// The model's value semantics.
///
/// These are what make `changedFigures` and the widget rebuilds honest: two
/// renders that carry the same strings must compare equal, and one that
/// carries a different display string must not.
void main() {
  const figure = OrderTicketFigure(
    name: 'notional',
    label: 'Order value',
    display: r'$64,250.00',
  );
  const field = OrderTicketField(
    option: 'side',
    label: 'Side',
    control: OrderTicketControl.choice,
    value: 'buy',
    choices: <String>['buy', 'sell'],
    pattern: null,
  );

  group(OrderTicketFigure, () {
    test('two figures with the same display string are equal', () {
      expect(
        figure,
        equals(
          const OrderTicketFigure(
            name: 'notional',
            label: 'Order value',
            display: r'$64,250.00',
          ),
        ),
      );
    });

    test('a different display string is a different figure', () {
      expect(
        figure,
        isNot(
          equals(
            const OrderTicketFigure(
              name: 'notional',
              label: 'Order value',
              display: r'$99,000.00',
            ),
          ),
        ),
      );
    });
  });

  group(OrderTicketField, () {
    test('two descriptors of the same option are equal', () {
      expect(
        field,
        equals(
          const OrderTicketField(
            option: 'side',
            label: 'Side',
            control: OrderTicketControl.choice,
            value: 'buy',
            choices: <String>['buy', 'sell'],
            pattern: null,
          ),
        ),
      );
    });

    test('a different current value is a different descriptor', () {
      expect(
        field,
        isNot(
          equals(
            const OrderTicketField(
              option: 'side',
              label: 'Side',
              control: OrderTicketControl.choice,
              value: 'sell',
              choices: <String>['buy', 'sell'],
              pattern: null,
            ),
          ),
        ),
      );
    });
  });

  group(OrderTicketData, () {
    test('two readings of one payload are equal', () {
      expect(
        readOrderTicket(orderTicketExample()),
        equals(readOrderTicket(orderTicketExample())),
      );
    });

    test('a payload with a changed figure is a different reading', () {
      expect(
        readOrderTicket(orderTicketExample()),
        isNot(
          equals(readOrderTicket(orderTicketExampleWithNotional(r'$1.00'))),
        ),
      );
    });
  });
}
