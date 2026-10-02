import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_changes.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_figure_tile.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_impact.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_notice.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'order_ticket_v2_harness.dart';

void main() {
  group(OrderTicketV2Impact, () {
    Future<void> pump(
      WidgetTester tester, {
      Map<String, dynamic>? example,
      Set<String> changed = const <String>{},
      String? rejection,
      Brightness brightness = Brightness.light,
    }) => tester.pumpApp(
      Scaffold(
        body: SingleChildScrollView(
          child: OrderTicketV2Impact(
            data: readTicketV2(example ?? ticketV2Example()),
            changed: changed,
            rejection: rejection,
          ),
        ),
      ),
      brightness: brightness,
    );

    testWidgets('renders the money figures with their server labels', (
      tester,
    ) async {
      await pump(tester);
      final tiles = tester.widgetList<OrderTicketV2FigureTile>(
        find.byType(OrderTicketV2FigureTile),
      );
      // Three, not four. The `units` tile carried the arithmetic sum of every
      // leg's quantity under the label *Est. shares*; units of different
      // assets do not add, so the backend stopped sending it (GGU-122,
      // backend spec 0046 OD-2) and nothing took its place.
      expect(tiles.map((tile) => tile.figure.name), <String>[
        'total',
        'fees',
        'cash',
      ]);
      for (final tile in tiles) {
        expect(find.text(tile.figure.label), findsOneWidget);
        expect(find.text(tile.figure.display), findsOneWidget);
        expect(tile.isChanged, isFalse);
        expect(tile.isNegative, isFalse);
      }
      expect(find.text(OrderTicketV2Impact.noteAtRest), findsOneWidget);
    });

    testWidgets('marks only the figures named as changed, and says so', (
      tester,
    ) async {
      // AC-5: the mark follows the slot name decided upstream, the caption
      // flips to `just recomputed` and the panel takes the tint.
      final handle = tester.ensureSemantics();
      await pump(tester, changed: const <String>{'total'});
      final tiles = tester.widgetList<OrderTicketV2FigureTile>(
        find.byType(OrderTicketV2FigureTile),
      );
      for (final tile in tiles) {
        expect(tile.isChanged, tile.figure.name == 'total');
      }
      expect(find.text(OrderTicketV2Impact.noteAfterStep), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape('${OrderTicketV2Impact.caption}, updated')),
        ),
        findsOneWidget,
      );
      final panel = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(OrderTicketV2Impact),
              matching: find.byType(DecoratedBox),
              matchRoot: true,
            )
            .first,
      );
      final decoration = panel.decoration as BoxDecoration;
      expect(decoration.color, OrderTicketV2Tokens.light.changedSurface);
      handle.dispose();
    });

    testWidgets('shows the weight row and marks its after figure', (
      tester,
    ) async {
      final data = readTicketV2(ticketV2Example());
      final shift = data.shifts.first;
      await pump(tester, changed: <String>{LineSlots.shift(shift.key)});
      expect(find.text(shift.label), findsOneWidget);
      expect(find.text(shift.beforeDisplay), findsOneWidget);
      final after = tester.widget<Text>(find.text(shift.afterDisplay));
      expect(after.style?.color, OrderTicketV2Tokens.light.changed);
    });

    testWidgets('a blocked draft shows the notice and reddens the cash', (
      tester,
    ) async {
      // AC-3: the flag and the sentence are the backend's; the colour follows
      // the flag, never the sign of a parsed string.
      final message =
          ticketV2ExampleBlocked()['constraints'] as Map<String, dynamic>;
      await pump(tester, example: ticketV2ExampleBlocked());
      expect(find.byType(OrderTicketV2Notice), findsOneWidget);
      expect(find.text(message['message']! as String), findsOneWidget);
      final cash = tester
          .widgetList<OrderTicketV2FigureTile>(
            find.byType(OrderTicketV2FigureTile),
          )
          .singleWhere((tile) => tile.figure.name == 'cash');
      expect(cash.isNegative, isTrue);
      final figure = tester.widget<Text>(find.text(cash.figure.display));
      expect(figure.style?.color, OrderTicketV2Tokens.light.negative);
    });

    testWidgets('a refused edit shows its detail without dropping the panel', (
      tester,
    ) async {
      await pump(tester, rejection: 'legs must match the pattern');
      expect(find.byType(OrderTicketV2Notice), findsOneWidget);
      expect(find.text('legs must match the pattern'), findsOneWidget);
      expect(find.byType(OrderTicketV2FigureTile), findsNWidgets(3));
    });
  });
}
