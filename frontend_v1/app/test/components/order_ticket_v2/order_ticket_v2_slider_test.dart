import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_model.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_weight_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'order_ticket_v2_harness.dart';

/// The weight bar as a slider (backend spec 0050).
///
/// The bar used to say of itself *"it is not a slider — dragging one would
/// turn a pixel into a share count"*. It can be one now because a drag picks
/// a **stop**: `lines[].stops` is a list of whole `legs` values the backend
/// wrote, so a pixel becomes an index into a list and never a quantity.
/// These tests assert exactly that — what is sent is always a value that
/// arrived.
void main() {
  group(OrderTicketV2WeightBar, () {
    OrderTicketV2Line first() => readTicketV2(ticketV2Example()).lines.first;

    Future<void> pump(
      WidgetTester tester, {
      required OrderTicketV2Line line,
      ValueChanged<String>? onLegsChanged,
      double width = 400,
    }) => tester.pumpApp(
      Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: OrderTicketV2WeightBar(
              fraction: line.weight,
              display: line.weightDisplay,
              isChanged: false,
              ringColor: const Color(0xFFFFFFFF),
              stops: line.stops,
              onLegsChanged: onLegsChanged,
            ),
          ),
        ),
      ),
    );

    testWidgets('sends a value the backend wrote, never one it composed', (
      tester,
    ) async {
      // The claim that lets this be a slider at all (N-2).
      final line = first();
      final sent = <String>[];
      await pump(tester, line: line, onLegsChanged: sent.add);

      await tester.tapAt(tester.getCenter(find.byType(OrderTicketV2WeightBar)));
      await tester.pump();

      expect(sent, hasLength(1));
      expect(line.stops, contains(sent.single));
    });

    testWidgets('a drag to the far left sends the first stop', (tester) async {
      final line = first();
      final sent = <String>[];
      await pump(tester, line: line, onLegsChanged: sent.add);
      final box = tester.getRect(find.byType(OrderTicketV2WeightBar));

      await tester.dragFrom(box.centerLeft + const Offset(4, 0), Offset.zero);
      await tester.pump();

      expect(sent.last, equals(line.stops.first));
    });

    testWidgets('a drag past the far right sends the last stop, not an error', (
      tester,
    ) async {
      // The gesture is clamped, so a fling off the end is the maximum rather
      // than a range error.
      final line = first();
      final sent = <String>[];
      await pump(tester, line: line, onLegsChanged: sent.add);
      final box = tester.getRect(find.byType(OrderTicketV2WeightBar));

      await tester.dragFrom(box.centerLeft, Offset(box.width * 3, 0));
      await tester.pump();

      expect(sent.last, equals(line.stops.last));
    });

    testWidgets('does not move when no host can honour an edit', (
      tester,
    ) async {
      // The same condition that disables the stepper: a card rendered where
      // nothing is listening does not pretend to be interactive.
      final line = first();
      await pump(tester, line: line);

      await tester.tapAt(tester.getCenter(find.byType(OrderTicketV2WeightBar)));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not move when the draft has no mix to move', (
      tester,
    ) async {
      // A one-stop ladder: a single-leg draft, or one whose others are zero.
      // Dragging it would send the value it already has.
      final line = first();
      final sent = <String>[];
      await pump(
        tester,
        line: OrderTicketV2Line(
          key: line.key,
          symbol: line.symbol,
          name: line.name,
          priceDisplay: line.priceDisplay,
          quantityDisplay: line.quantityDisplay,
          notionalDisplay: line.notionalDisplay,
          weightDisplay: line.weightDisplay,
          weight: line.weight,
          increment: line.increment,
          decrement: line.decrement,
          stops: <String>[line.stops.first],
          position: 0,
        ),
        onLegsChanged: sent.add,
      );

      await tester.tapAt(tester.getCenter(find.byType(OrderTicketV2WeightBar)));
      await tester.pump();

      expect(sent, isEmpty);
    });

    testWidgets('draws the thumb at the weight, not at the stop index', (
      tester,
    ) async {
      // The two agree to within one stride by construction, and where they
      // differ the printed percentage is the truth.
      final line = first();
      await pump(tester, line: line, onLegsChanged: (_) {});
      final bar = tester.getRect(find.byType(OrderTicketV2WeightBar));
      final handle = tester.getRect(find.byType(DecoratedBox).last);

      final fraction = (handle.center.dx - bar.left) / bar.width;
      expect(fraction, closeTo(line.weight, 0.1));
    });
  });
}
