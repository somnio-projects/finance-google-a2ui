import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_header.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'order_ticket_v2_harness.dart';

void main() {
  group(OrderTicketV2Header, () {
    Future<void> pump(
      WidgetTester tester, {
      Map<String, dynamic>? example,
      Set<String> stepped = const <String>{},
      Brightness brightness = Brightness.light,
    }) => tester.pumpApp(
      Scaffold(
        body: OrderTicketV2Header(
          data: readTicketV2(example ?? ticketV2Example()),
          stepped: stepped,
        ),
      ),
      brightness: brightness,
    );

    testWidgets('draws the server title in the caption case', (tester) async {
      // The backend writes `Draft order · Buy · 3 legs`; the artboard sets it
      // with `text-transform: uppercase`, which is typography, not a rewrite.
      await pump(tester);
      final title = ticketV2Example()['title']! as String;
      expect(find.text(title.toUpperCase()), findsOneWidget);
    });

    testWidgets('shows the backend badge at rest', (tester) async {
      await pump(tester);
      expect(find.text('editable'), findsOneWidget);
      final pill = tester.widget<Text>(find.text('editable'));
      expect(pill.style?.color, OrderTicketV2Tokens.chromeLight.pillText);
    });

    testWidgets('shows `blocked` in the blocked chrome', (tester) async {
      await pump(tester, example: ticketV2ExampleBlocked());
      final pill = tester.widget<Text>(find.text('blocked'));
      expect(
        pill.style?.color,
        OrderTicketV2Tokens.chromeLight.blockedPillText,
      );
    });

    testWidgets('names the stepped leg once one has been recomputed', (
      tester,
    ) async {
      // OD-2: the design's pill reads `NVDA +$2,000`; the delta is arithmetic
      // this client may not do, so the pill carries the symbol and the word.
      final key = readTicketV2(ticketV2Example()).lines.first.key;
      await pump(tester, stepped: <String>{key}, brightness: Brightness.dark);
      final text = '$key · ${OrderTicketV2Header.recomputedWord}';
      expect(find.text(text), findsOneWidget);
      final pill = tester.widget<Text>(find.text(text));
      expect(
        pill.style?.color,
        OrderTicketV2Tokens.chromeDark.recomputedPillText,
      );
      expect(find.text('editable'), findsNothing);
    });

    testWidgets('a blocked draft stays blocked even after a step', (
      tester,
    ) async {
      final key = readTicketV2(ticketV2Example()).lines.first.key;
      await pump(
        tester,
        example: ticketV2ExampleBlocked(),
        stepped: <String>{key},
      );
      expect(find.text('blocked'), findsOneWidget);
    });
  });
}
