import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_card.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_impact.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'order_ticket_v2_harness.dart';

void main() {
  group(OrderTicketV2Card, () {
    Future<void> pumpAt(
      WidgetTester tester,
      double width, {
      Brightness brightness = Brightness.light,
      bool isBusy = false,
      ValueChanged<String>? onLegsChanged,
    }) => tester.pumpApp(
      Scaffold(
        body: SingleChildScrollView(
          child: OrderTicketV2Card(
            data: readTicketV2(ticketV2Example()),
            isBusy: isBusy,
            onLegsChanged: onLegsChanged,
          ),
        ),
      ),
      brightness: brightness,
      surfaceSize: Size(width, 1600),
    );

    BoxDecoration cardDecoration(WidgetTester tester) {
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(OrderTicketV2Card),
              matching: find.byType(DecoratedBox),
              matchRoot: true,
            )
            .first,
      );
      return box.decoration as BoxDecoration;
    }

    testWidgets('lays out at phone width without overflowing', (tester) async {
      // AC-6. 390 is the width the flow's phone artboards are drawn at.
      await pumpAt(tester, 390);
      expect(tester.takeException(), isNull);
      expect(find.byType(OrderTicketV2Impact), findsOneWidget);
    });

    testWidgets("lays out at the design's desktop width", (tester) async {
      await pumpAt(tester, 1024);
      expect(tester.takeException(), isNull);
    });

    testWidgets("carries the design's measured chrome, light", (tester) async {
      // AC-6, on the **rendered** decoration: radius 16, padding 16x18, the
      // artboard's surface and hairline.
      await pumpAt(tester, 1024);
      final decoration = cardDecoration(tester);
      expect(decoration.color, OrderTicketV2Tokens.light.surface);
      expect(decoration.border?.top.color, OrderTicketV2Tokens.light.border);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(OrderTicketV2Card.radius),
      );
      expect(OrderTicketV2Card.radius, 16);
      expect(
        OrderTicketV2Card.padding,
        const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      );
    });

    testWidgets("carries the design's measured chrome, dark", (tester) async {
      await pumpAt(tester, 1024, brightness: Brightness.dark);
      final decoration = cardDecoration(tester);
      expect(decoration.color, OrderTicketV2Tokens.dark.surface);
      expect(decoration.border?.top.color, OrderTicketV2Tokens.dark.border);
    });

    testWidgets('holds the steppers while a re-request is in flight', (
      tester,
    ) async {
      // AC-4: the previous figures stay readable and no second edit is sent
      // until the backend has answered the first.
      await pumpAt(tester, 1024, isBusy: true, onLegsChanged: (_) {});
      final taps = tester.widgetList<InkWell>(find.byType(InkWell));
      expect(taps, isNotEmpty);
      for (final tap in taps) {
        expect(tap.onTap, isNull);
      }
    });

    testWidgets('enables the steppers when a host can honour an edit', (
      tester,
    ) async {
      await pumpAt(tester, 1024, onLegsChanged: (_) {});
      final enabled = tester
          .widgetList<InkWell>(find.byType(InkWell))
          .where((tap) => tap.onTap != null);
      expect(enabled, isNotEmpty);
    });
  });
}
