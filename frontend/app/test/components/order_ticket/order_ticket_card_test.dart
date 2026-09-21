import 'package:finance_app/components/order_ticket/order_ticket_card.dart';
import 'package:finance_app/components/order_ticket/order_ticket_component.dart';
import 'package:finance_app/components/order_ticket/order_ticket_impact.dart';
import 'package:finance_app/components/order_ticket/order_ticket_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'order_ticket_harness.dart';

void main() {
  group(OrderTicketCard, () {
    const component = OrderTicketComponent();

    Future<void> pumpAt(
      WidgetTester tester,
      double width, {
      String? rejection,
      Set<String> changed = const <String>{},
      void Function(String, String)? onChanged,
    }) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // A Scaffold, because that is what hosts the card in both real
      // surfaces and the form controls need a Material ancestor.
      await tester.pumpApp(
        Scaffold(
          body: SingleChildScrollView(
            child: OrderTicketCard(
              data: component.read(orderTicketPayload()),
              rejection: rejection,
              changedFigures: changed,
              onOptionChanged: onChanged,
            ),
          ),
        ),
      );
    }

    testWidgets('lays out at phone width without overflowing', (tester) async {
      // AC-13. The figures and controls stack below the breakpoint.
      await pumpAt(tester, 390);
      expect(tester.takeException(), isNull);
      final impact = tester.widget<OrderTicketImpact>(
        find.byType(OrderTicketImpact),
      );
      expect(impact.isWide, isFalse);
    });

    testWidgets("lays out at the design's desktop width", (tester) async {
      // AC-13. 1024 is the width both artboards are drawn at.
      await pumpAt(tester, 1024);
      expect(tester.takeException(), isNull);
      final impact = tester.widget<OrderTicketImpact>(
        find.byType(OrderTicketImpact),
      );
      expect(impact.isWide, isTrue);
    });

    testWidgets("carries the design's measured chrome as rendered", (
      tester,
    ) async {
      // AC-16, measured off an HTTP render of the catalog artboard at 1024:
      // card radius 16 and padding 16x18, panel radius 14 and padding 13x15,
      // 1 px borders. Asserted on the **rendered** decoration — comparing
      // the constants with their own literals would stay green if the widget
      // stopped using them, which is what the first version of this test did.
      await pumpAt(tester, 1024);

      final card = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(OrderTicketCard),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final cardBox = card.decoration as BoxDecoration;
      expect(cardBox.borderRadius, BorderRadius.circular(16));
      expect(cardBox.border!.top.width, 1);
      expect(
        tester
            .widget<Padding>(
              find
                  .descendant(
                    of: find.byType(OrderTicketCard),
                    matching: find.byType(Padding),
                  )
                  .first,
            )
            .padding,
        const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      );

      final panel = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(OrderTicketImpact),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final panelBox = panel.decoration as BoxDecoration;
      expect(panelBox.borderRadius, BorderRadius.circular(14));
      expect(panelBox.border!.top.width, 1);
    });

    testWidgets('shows a rejection without dropping the disclosure', (
      tester,
    ) async {
      // AC-5 and AC-11 together: the notice appears and the compliance
      // statement is still rendered, in the state where it matters most.
      await pumpAt(tester, 1024, rejection: 'size must match the pattern');
      expect(find.byType(OrderTicketNotice), findsOneWidget);
      expect(find.text('size must match the pattern'), findsOneWidget);
      expect(
        find.text(orderTicketExample()['disclosure']! as String),
        findsOneWidget,
      );
    });

    testWidgets('shows no notice when nothing was rejected', (tester) async {
      await pumpAt(tester, 1024);
      expect(find.byType(OrderTicketNotice), findsNothing);
    });

    testWidgets('shows the side the payload declares', (tester) async {
      await pumpAt(tester, 1024);
      expect(find.text(orderTicketExample()['side']! as String), findsWidgets);
    });
  });
}
