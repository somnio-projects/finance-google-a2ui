import 'package:finance_app/components/order_ticket/order_ticket_component.dart';
import 'package:finance_app/components/order_ticket/order_ticket_inputs.dart';
import 'package:finance_app/components/order_ticket/order_ticket_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'order_ticket_harness.dart';

/// The declared bound, at the control surface.
///
/// Split from `order_ticket_inputs_test.dart` along the seam that was already
/// there: that file covers *how a control is presented*, this one covers
/// *what it will accept and send*. AC-6 and N-8 live here.
void main() {
  group('the declared bound', () {
    const component = OrderTicketComponent();
    late List<OrderTicketField> fields;
    late List<(String, String)> sent;

    setUp(() {
      fields = component.read(orderTicketPayload()).fields;
      sent = <(String, String)>[];
    });

    Future<void> pump(WidgetTester tester) => tester.pumpApp(
      Scaffold(
        body: SingleChildScrollView(
          child: OrderTicketInputs(
            fields: fields,
            onChanged: (o, v) => sent.add((o, v)),
            pendingOption: null,
            isWide: false,
          ),
        ),
      ),
    );

    testWidgets('offers exactly the declared choices', (tester) async {
      // AC-6: the menu is the server's `choices` and nothing else.
      await pump(tester);
      final field = fields.firstWhere(
        (f) => f.control == OrderTicketControl.choice,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      for (final choice in field.choices) {
        expect(find.text(choice), findsWidgets);
      }
    });

    testWidgets('sends the option of the same name when a choice is picked', (
      tester,
    ) async {
      // AC-1: the event carries the payload's own `option`, never a name
      // this widget chose.
      await pump(tester);
      final field = fields.firstWhere(
        (f) => f.control == OrderTicketControl.choice,
      );
      final other = field.choices.firstWhere((c) => c != field.value);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(other).last);
      await tester.pumpAndSettle();
      expect(sent, equals(<(String, String)>[(field.option, other)]));
    });

    testWidgets('declares the server pattern and invents no bound', (
      tester,
    ) async {
      // AC-6 / N-8. The pattern is shown as the accepted shape; it is never
      // compiled or used to block input, because the 422 is the authority.
      await pump(tester);
      final field = fields.firstWhere(
        (f) => f.control == OrderTicketControl.text,
      );
      expect(field.pattern, isNotNull);
      expect(find.text(field.pattern!), findsOneWidget);
    });

    testWidgets('sends an out-of-bounds value rather than clamping it', (
      tester,
    ) async {
      // AC-6, and the sharp end of N-8: the client must not silently correct
      // a value the backend would refuse. It sends it, and the rejection is
      // what the reader sees.
      await pump(tester);
      final field = fields.firstWhere(
        (f) => f.control == OrderTicketControl.text,
      );
      await tester.enterText(find.byType(TextFormField).first, 'not-a-number');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(sent, equals(<(String, String)>[(field.option, 'not-a-number')]));
    });
  });
}
