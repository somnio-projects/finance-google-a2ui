import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_quantity_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group(OrderTicketV2QuantityField, () {
    const entry = 'BTC:{units},ETH:1.0';

    Future<List<String>> pump(
      WidgetTester tester, {
      String display = '0.6',
      String? template = entry,
      bool live = true,
    }) async {
      final sent = <String>[];
      await tester.pumpApp(
        Scaffold(
          body: Center(
            child: OrderTicketV2QuantityField(
              display: display,
              entry: template,
              color: Colors.black,
              onLegsChanged: live ? sent.add : null,
            ),
          ),
        ),
      );
      return sent;
    }

    testWidgets('shows the backend display string', (tester) async {
      await pump(tester);
      expect(find.text('0.6'), findsOneWidget);
    });

    testWidgets('a typed quantity is put in the hole verbatim', (tester) async {
      final sent = await pump(tester);
      await tester.enterText(find.byType(TextField), ' 0.25 ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(sent, <String>['BTC:0.25,ETH:1.0']);
    });

    testWidgets('submitting the value on screen sends nothing', (tester) async {
      final sent = await pump(tester);
      await tester.enterText(find.byType(TextField), '0.6');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(sent, isEmpty);
    });

    testWidgets('tapping outside submits what was typed', (tester) async {
      final sent = await pump(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '2');
      await tester.tapAt(Offset.zero);
      await tester.pump();
      expect(sent, <String>['BTC:2,ETH:1.0']);
      await tester.tapAt(Offset.zero);
      expect(sent, hasLength(1));
    });

    testWidgets('is read-only without a template or a host', (tester) async {
      await pump(tester, template: null);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      await pump(tester, live: false);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    });

    testWidgets('a read-only field sends nothing on submit', (tester) async {
      final sent = await pump(tester, template: null);
      await tester.enterText(find.byType(TextField), '3');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(sent, isEmpty);
    });

    testWidgets('a new render resets the text to the new display', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), '9');
      await pump(tester, display: '0.61');
      expect(find.text('0.61'), findsOneWidget);
    });
  });
}
