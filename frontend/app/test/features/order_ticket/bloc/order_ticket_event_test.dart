import 'package:finance_app/features/order_ticket/bloc/order_ticket_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// The events' value semantics.
///
/// `OrderTicketOptionChanged` is compared by *(option, value)*, which is what
/// lets a bloc test assert that the right option was sent with the right
/// value rather than merely that something was sent.
void main() {
  group(OrderTicketEvent, () {
    test('a request carries nothing to distinguish it', () {
      expect(
        const OrderTicketRequested(),
        equals(const OrderTicketRequested()),
      );
      expect(const OrderTicketRequested().props, isEmpty);
    });

    test('a reload carries nothing to distinguish it', () {
      expect(const OrderTicketReloaded(), equals(const OrderTicketReloaded()));
    });

    test('an option change is its option and its value', () {
      const change = OrderTicketOptionChanged(option: 'side', value: 'sell');
      expect(
        change,
        equals(const OrderTicketOptionChanged(option: 'side', value: 'sell')),
      );
      expect(change.props, equals(<Object?>['side', 'sell']));
    });

    test('the same value on a different option is a different event', () {
      expect(
        const OrderTicketOptionChanged(option: 'side', value: 'sell'),
        isNot(
          equals(const OrderTicketOptionChanged(option: 'size', value: 'sell')),
        ),
      );
    });

    test('a request and a reload are not the same event', () {
      expect(
        const OrderTicketRequested(),
        isNot(equals(const OrderTicketReloaded())),
      );
    });
  });
}
