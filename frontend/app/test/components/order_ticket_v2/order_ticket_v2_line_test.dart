import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_changes.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_line.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_model.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_stepper.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_tokens.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_weight_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'order_ticket_v2_harness.dart';

void main() {
  group(OrderTicketV2LineTile, () {
    late OrderTicketV2Line line;

    setUp(() => line = readTicketV2(ticketV2Example()).lines.first);

    Future<void> pump(
      WidgetTester tester, {
      OrderTicketV2Line? subject,
      bool isStepped = false,
      Set<String> changed = const <String>{},
      ValueChanged<String>? onLegsChanged,
      Brightness brightness = Brightness.light,
    }) => tester.pumpApp(
      Scaffold(
        body: OrderTicketV2LineTile(
          line: subject ?? line,
          isStepped: isStepped,
          changed: changed,
          onLegsChanged: onLegsChanged,
        ),
      ),
      brightness: brightness,
    );

    testWidgets('a + tap sends the increment the backend wrote, unchanged', (
      tester,
    ) async {
      // AC-2: no arithmetic — the string handed over is the string sent.
      final sent = <String>[];
      await pump(tester, onLegsChanged: sent.add);
      await tester.tap(
        find.bySemanticsLabel(OrderTicketV2Stepper.increaseLabel(line.symbol)),
      );
      expect(sent, equals(<String>[line.increment!]));
    });

    testWidgets('a - tap sends the decrement the backend wrote', (
      tester,
    ) async {
      final sent = <String>[];
      await pump(tester, onLegsChanged: sent.add);
      await tester.tap(
        find.bySemanticsLabel(OrderTicketV2Stepper.decreaseLabel(line.symbol)),
      );
      expect(sent, equals(<String>[line.decrement!]));
    });

    testWidgets('a side at the published bound is disabled, not clamped', (
      tester,
    ) async {
      // AC-3: `decrement` null at zero shares means the control is off; the
      // client never invents `-1` and never sends a value to be refused.
      final atZero = OrderTicketV2Line(
        key: line.key,
        symbol: line.symbol,
        name: line.name,
        priceDisplay: line.priceDisplay,
        quantityDisplay: '0',
        notionalDisplay: r'$0.00',
        weightDisplay: '0.00%',
        weight: 0,
        increment: line.increment,
        decrement: null,
        stops: line.stops,
        position: 0,
      );
      await pump(tester, subject: atZero, onLegsChanged: (_) {});
      final taps = tester.widgetList<InkWell>(find.byType(InkWell)).toList();
      expect(taps.first.onTap, isNull);
      expect(taps.last.onTap, isNotNull);
    });

    testWidgets('takes the highlighted chrome when it was stepped', (
      tester,
    ) async {
      // AC-5: the design tints the stepped leg's card, rail and figures.
      await pump(
        tester,
        isStepped: true,
        changed: <String>{
          LineSlots.quantity(line.key),
          LineSlots.notional(line.key),
          LineSlots.weight(line.key),
        },
      );
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(OrderTicketV2LineTile),
              matching: find.byType(DecoratedBox),
              matchRoot: true,
            )
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, OrderTicketV2Tokens.light.changedSurface);
      expect(
        decoration.border?.top.color,
        OrderTicketV2Tokens.light.changedBorder,
      );
      final amount = tester.widget<Text>(find.text(line.notionalDisplay));
      expect(amount.style?.color, OrderTicketV2Tokens.light.changed);
      final stepper = tester.widget<OrderTicketV2Stepper>(
        find.byType(OrderTicketV2Stepper),
      );
      expect(stepper.isChanged, isTrue);
      final bar = tester.widget<OrderTicketV2WeightBar>(
        find.byType(OrderTicketV2WeightBar),
      );
      expect(bar.isChanged, isTrue);
      expect(bar.ringColor, OrderTicketV2Tokens.light.changedSurface);
    });

    testWidgets('draws at rest in the dark palette', (tester) async {
      await pump(tester, brightness: Brightness.dark);
      final amount = tester.widget<Text>(find.text(line.notionalDisplay));
      expect(amount.style?.color, OrderTicketV2Tokens.dark.text);
      final weight = tester.widget<Text>(find.text(line.weightDisplay));
      expect(weight.style?.color, OrderTicketV2Tokens.dark.subText);
    });

    testWidgets('labels the quantity for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      expect(
        find.bySemanticsLabel(OrderTicketV2Stepper.quantityLabel(line.symbol)),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
