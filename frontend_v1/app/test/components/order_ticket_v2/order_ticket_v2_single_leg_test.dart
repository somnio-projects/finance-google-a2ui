import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_card.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_model.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_stepper.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_weight_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'order_ticket_v2_harness.dart';

/// GGU-149: a one-stop slider is not drawn, and one press is one request.
void main() {
  OrderTicketV2Line oneStop(OrderTicketV2Line line) => OrderTicketV2Line(
    key: line.key,
    symbol: line.symbol,
    name: line.name,
    priceDisplay: line.priceDisplay,
    quantityDisplay: line.quantityDisplay,
    notionalDisplay: line.notionalDisplay,
    weightDisplay: '100.00%',
    weight: 1,
    increment: line.increment,
    decrement: line.decrement,
    stops: <String>[line.stops.first],
    position: 0,
  );

  group('$OrderTicketV2WeightBar with one stop (AC-1)', () {
    testWidgets('draws no track, no thumb and no drag, only the weight', (
      tester,
    ) async {
      final line = oneStop(readTicketV2(ticketV2Example()).lines.first);
      await tester.pumpApp(
        Scaffold(
          body: SizedBox(
            width: 300,
            child: OrderTicketV2WeightBar(
              fraction: line.weight,
              display: line.weightDisplay,
              isChanged: false,
              ringColor: const Color(0xFFFFFFFF),
              stops: line.stops,
              onLegsChanged: (_) {},
            ),
          ),
        ),
      );
      final bar = find.byType(OrderTicketV2WeightBar);
      for (final drawn in <Type>[GestureDetector, LayoutBuilder, Slider]) {
        expect(
          find.descendant(of: bar, matching: find.byType(drawn)),
          findsNothing,
          reason: '$drawn on a one-stop track',
        );
      }
      expect(find.text('100.00%'), findsOneWidget);
      expect(tester.getSemantics(bar), isSemantics(isSlider: false));
    });
  });

  group('$OrderTicketV2Card sends one edit at a time (AC-4)', () {
    late OrderTicketV2Data data;
    late List<String> sent;

    setUp(() {
      data = readTicketV2(ticketV2Example());
      sent = <String>[];
    });

    Future<void> pump(
      WidgetTester tester,
      OrderTicketV2Data data, {
      bool isBusy = false,
    }) => tester.pumpApp(
      Scaffold(
        body: SingleChildScrollView(
          child: OrderTicketV2Card(
            data: data,
            isBusy: isBusy,
            onLegsChanged: sent.add,
          ),
        ),
      ),
    );

    Finder plus(OrderTicketV2Data data) => find
        .bySemanticsLabel(
          OrderTicketV2Stepper.increaseLabel(data.lines.first.symbol),
        )
        .first;

    testWidgets("a rapid double tap sends the payload's value once", (
      tester,
    ) async {
      await pump(tester, data);
      await tester.tap(plus(data));
      await tester.tap(plus(data), warnIfMissed: false);
      await tester.pump();

      expect(sent, <String>[data.lines.first.increment!]);
    });

    testWidgets('a new payload opens the stepper again', (tester) async {
      await pump(tester, data);
      await tester.tap(plus(data));
      await tester.pump();
      final next = readTicketV2(ticketV2ExampleStepped());
      await pump(tester, next);
      await tester.tap(plus(next));
      await tester.pump();

      expect(sent, hasLength(2));
      expect(sent.last, next.lines.first.increment);
    });

    testWidgets('a settled request opens it again on the same payload', (
      tester,
    ) async {
      await pump(tester, data);
      await tester.tap(plus(data));
      await pump(tester, data, isBusy: true);
      await pump(tester, data);
      await tester.tap(plus(data));
      await tester.pump();

      expect(sent, hasLength(2));
    });
  });
}
