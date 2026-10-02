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
/// The choice after the current value — on screen once the menu opens,
/// where the first choice of a long list is not.
String neighbourOf(OrderTicketField field) {
  final index = field.choices.indexOf(field.value);
  return field.choices[(index + 1) % field.choices.length];
}

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
      // The open menu scrolls to the selected item and builds lazily, so
      // the declared list is read off the button rather than off the screen.
      final button = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>).first,
      );
      expect(button.items!.map((item) => item.value), field.choices);
      expect(button.value, field.value);
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
      final other = neighbourOf(field);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(other).last);
      await tester.pumpAndSettle();
      expect(sent, equals(<(String, String)>[(field.option, other)]));
    });

    testWidgets('shows the server hint and never the raw pattern', (
      tester,
    ) async {
      // AC-6 / N-8. This used to assert the opposite — that `pattern` was on
      // screen — and it passed while the app drew
      // `^[0-9]{1,9}(\.[0-9]{1,8})?$` under a form field. Accurate, and not
      // what a person reads.
      //
      // Both facts still travel: `hint` is the server's sentence for the
      // reader and `pattern` is the machine's copy. The client renders the
      // first and never the second, and it cannot derive one from the other
      // — N-5 bans interpreting a server-supplied string, which is exactly
      // why the sentence is written where the bound is (spec 0026).
      await pump(tester);
      final field = fields.firstWhere(
        (f) => f.control == OrderTicketControl.text,
      );
      expect(field.pattern, isNotNull);
      expect(field.hint, isNotNull);
      expect(find.text(field.hint!), findsOneWidget);
      expect(find.text(field.pattern!), findsNothing);
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
