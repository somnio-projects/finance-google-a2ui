import 'package:finance_app/components/order_ticket/order_ticket_card.dart';
import 'package:finance_app/components/order_ticket/order_ticket_component.dart';
import 'package:finance_app/components/surface_edits.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'order_ticket_harness.dart';

/// GGU-113: the ticket the Assistant returned rendered read-only because
/// `build` had no host to hand an edit to. A `SurfaceEdits` scope is that host.
void main() {
  group('$OrderTicketComponent inside a SurfaceEdits scope', () {
    const component = OrderTicketComponent();

    Widget subject({
      required void Function(String option, String value) onOptionChanged,
      String? pendingOption,
      String? rejection,
    }) => Scaffold(
      body: SingleChildScrollView(
        child: SurfaceEdits(
          onOptionChanged: onOptionChanged,
          pendingOption: pendingOption,
          rejection: rejection,
          child: Builder(
            builder: (context) =>
                component.build(context, orderTicketPayload()),
          ),
        ),
      ),
    );

    testWidgets('renders its declared inputs as live controls (AC-1)', (
      tester,
    ) async {
      await tester.pumpApp(subject(onOptionChanged: (_, _) {}));
      final card = tester.widget<OrderTicketCard>(find.byType(OrderTicketCard));
      expect(card.onOptionChanged, isNotNull);
      for (final field in tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      )) {
        expect(field.enabled, isTrue);
      }
    });

    testWidgets('a choice forwards the declared option and value (AC-2)', (
      tester,
    ) async {
      final edits = <(String, String)>[];
      await tester.pumpApp(
        subject(onOptionChanged: (option, value) => edits.add((option, value))),
      );
      final inputs = orderTicketExample()['inputs']! as List<dynamic>;
      final side = inputs.cast<Map<String, dynamic>>().firstWhere(
        (input) => input['option'] == 'side',
      );
      final choices = (side['choices']! as List<dynamic>).cast<String>();
      final other = choices.firstWhere((c) => c != side['value']);

      // `inputs[]` arrives in the contract's order (N-10): `symbol` is the
      // first choice control and `side` the second.
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text(other).last);
      await tester.pumpAndSettle();

      expect(edits, <(String, String)>[('side', other)]);
    });

    testWidgets("draws the host's answer: the busy option and a refusal", (
      tester,
    ) async {
      await tester.pumpApp(
        subject(
          onOptionChanged: (_, _) {},
          pendingOption: 'size',
          rejection: 'size must be a positive number',
        ),
      );
      final card = tester.widget<OrderTicketCard>(find.byType(OrderTicketCard));
      expect(card.pendingOption, 'size');
      expect(find.text('size must be a positive number'), findsOneWidget);
    });
  });
}
