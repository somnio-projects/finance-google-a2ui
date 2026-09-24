import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_buttons.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group(OrderTicketV2Buttons, () {
    Future<void> pump(
      WidgetTester tester, {
      Brightness brightness = Brightness.light,
    }) => tester.pumpApp(
      const Scaffold(body: OrderTicketV2Buttons()),
      brightness: brightness,
    );

    testWidgets('draws the placeholders disabled, in the dark chrome', (
      tester,
    ) async {
      // OD-3: a button nothing can be reviewed through is drawn as the design
      // draws one that cannot be pressed, and says so to a screen reader.
      final handle = tester.ensureSemantics();
      await pump(tester, brightness: Brightness.dark);
      expect(find.text(OrderTicketV2Buttons.reviewLabel), findsOneWidget);
      expect(find.text(OrderTicketV2Buttons.saveLabel), findsOneWidget);
      final label = tester.widget<Text>(
        find.text(OrderTicketV2Buttons.reviewLabel),
      );
      expect(label.style?.color, OrderTicketV2Tokens.chromeDark.buttonText);
      expect(
        find.bySemanticsLabel(OrderTicketV2Buttons.reviewLabel),
        findsOneWidget,
      );
      final node = tester.getSemantics(
        find.bySemanticsLabel(OrderTicketV2Buttons.reviewLabel),
      );
      expect(node.hint, OrderTicketV2Buttons.unavailable);
      handle.dispose();
    });

    testWidgets('draws the light chrome the catalog gives a dead button', (
      tester,
    ) async {
      await pump(tester);
      final label = tester.widget<Text>(
        find.text(OrderTicketV2Buttons.reviewLabel),
      );
      expect(label.style?.color, OrderTicketV2Tokens.chromeLight.buttonText);
      final save = tester.widget<Text>(
        find.text(OrderTicketV2Buttons.saveLabel),
      );
      expect(save.style?.color, OrderTicketV2Tokens.chromeLight.buttonText);
    });
  });
}
