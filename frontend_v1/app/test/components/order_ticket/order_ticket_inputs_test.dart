import 'package:finance_app/components/order_ticket/order_ticket_busy_dot.dart';
import 'package:finance_app/components/order_ticket/order_ticket_component.dart';
import 'package:finance_app/components/order_ticket/order_ticket_field_control.dart';
import 'package:finance_app/components/order_ticket/order_ticket_inputs.dart';
import 'package:finance_app/components/order_ticket/order_ticket_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'order_ticket_harness.dart';

void main() {
  group(OrderTicketInputs, () {
    const component = OrderTicketComponent();
    late List<OrderTicketField> fields;
    late List<(String, String)> sent;

    setUp(() {
      fields = component.read(orderTicketPayload()).fields;
      sent = <(String, String)>[];
    });

    Future<void> pump(
      WidgetTester tester, {
      bool editable = true,
      String? pending,
      // A Scaffold, because that is what hosts these controls in both real
      // surfaces and a form field needs a Material ancestor.
    }) => tester.pumpApp(
      Scaffold(
        body: SingleChildScrollView(
          child: OrderTicketInputs(
            fields: fields,
            onChanged: editable ? (o, v) => sent.add((o, v)) : null,
            pendingOption: pending,
            isWide: false,
          ),
        ),
      ),
    );

    testWidgets('labels every control for a screen reader', (tester) async {
      // AC-12: an editable widget with unlabelled fields is not done. The
      // label is the server-written one, so a rename arrives without a code
      // change.
      final handle = tester.ensureSemantics();
      await pump(tester);
      for (final field in fields) {
        // A RegExp, because a control's accessible name is its label merged
        // with the value a screen reader reads after it ("Side\nbuy"). The
        // claim is that the server-written label is in there, not that it is
        // the whole of it.
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(field.label))),
          findsWidgets,
          reason: '"${field.option}" has no screen-reader label',
        );
      }
      handle.dispose();
    });

    // What a control accepts and sends is asserted in
    // `order_ticket_bounds_test.dart` — same subject, split for the budget.

    testWidgets('marks the pending option busy', (tester) async {
      // AC-8: a control being re-rendered is busy, not broken.
      await pump(tester, pending: fields.first.option);
      expect(find.byType(OrderTicketBusyDot), findsOneWidget);
    });

    testWidgets('disables every control when no host can honour an edit', (
      tester,
    ) async {
      // AC-10.
      await pump(tester, editable: false);
      final dropdowns = tester.widgetList<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdowns, isNotEmpty);
      for (final dropdown in dropdowns) {
        expect(dropdown.onChanged, isNull);
      }
      expect(sent, isEmpty);
    });

    testWidgets('lays the controls out in a row when wide', (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: OrderTicketInputs(
            fields: fields,
            onChanged: (o, v) => sent.add((o, v)),
            pendingOption: null,
            isWide: true,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      // A Row, not a Column — otherwise this test passes in either branch
      // and only proves the line executed.
      expect(
        find.descendant(
          of: find.byType(OrderTicketInputs),
          matching: find.byType(Row),
        ),
        findsWidgets,
      );
      final controls = tester
          .widgetList<OrderTicketFieldControl>(
            find.byType(OrderTicketFieldControl),
          )
          .toList();
      expect(controls, hasLength(fields.length));
      final first = tester.getTopLeft(
        find.byType(OrderTicketFieldControl).at(0),
      );
      final second = tester.getTopLeft(
        find.byType(OrderTicketFieldControl).at(1),
      );
      expect(second.dx, greaterThan(first.dx));
      expect(second.dy, equals(first.dy));
    });
  });
}
