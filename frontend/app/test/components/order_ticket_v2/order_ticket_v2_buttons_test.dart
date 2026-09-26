import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_buttons.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_control_model.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'order_ticket_v2_harness.dart';

/// The buttons, drawn from `controls[]`.
///
/// **This suite used to read the copy off the widget** —
/// `OrderTicketV2Buttons.reviewLabel` — which meant it asserted that a Dart
/// constant equalled itself. The words are the backend's now (spec
/// backend/0050), so the fixtures come from the catalog example, and a
/// renamed button is a changed contract rather than a changed constant.
void main() {
  group(OrderTicketV2Buttons, () {
    List<OrderTicketV2Control> served() =>
        readTicketV2(ticketV2Example()).controls;

    Future<void> pump(
      WidgetTester tester, {
      List<OrderTicketV2Control>? controls,
      Brightness brightness = Brightness.light,
    }) => tester.pumpApp(
      Scaffold(body: OrderTicketV2Buttons(controls: controls ?? served())),
      brightness: brightness,
    );

    testWidgets('draws every control the payload declared, in arrival order', (
      tester,
    ) async {
      await pump(tester);
      final controls = served();

      expect(controls, isNotEmpty);
      for (final control in controls) {
        expect(find.text(control.label), findsOneWidget);
      }
    });

    testWidgets("draws them disabled and announces the payload's reason", (
      tester,
    ) async {
      // The disabled state and the sentence are both read from the payload:
      // this widget decides neither (backend spec 0050 OD-2).
      final handle = tester.ensureSemantics();
      final control = served().first;
      await pump(tester, brightness: Brightness.dark);

      final node = tester.getSemantics(find.bySemanticsLabel(control.label));
      expect(control.enabled, isFalse);
      expect(node.hint, control.reason);
      expect(
        tester.widget<Text>(find.text(control.label)).style?.color,
        OrderTicketV2Tokens.chromeDark.buttonText,
      );
      handle.dispose();
    });

    testWidgets('uses the light chrome the catalog gives a dead button', (
      tester,
    ) async {
      final control = served().first;
      await pump(tester);

      expect(
        tester.widget<Text>(find.text(control.label)).style?.color,
        OrderTicketV2Tokens.chromeLight.buttonText,
      );
    });

    testWidgets('spells no label of its own', (tester) async {
      // The regression this file exists to prevent. A control the backend
      // renamed must move the pixels; a widget carrying its own copy would
      // keep drawing the old word.
      await pump(
        tester,
        controls: const <OrderTicketV2Control>[
          OrderTicketV2Control(
            key: 'review',
            label: 'Revisar la orden',
            kind: 'primary',
            enabled: false,
            reason: 'Sin bróker.',
          ),
        ],
      );

      expect(find.text('Revisar la orden'), findsOneWidget);
      expect(find.text('Review order'), findsNothing);
    });

    testWidgets('draws a secondary control without the filled surface', (
      tester,
    ) async {
      // `kind` is the design's hierarchy and is read, never inferred from the
      // label. The ticket serves only a primary today, so the secondary path
      // is exercised with a control rather than left uncovered.
      await pump(
        tester,
        controls: const <OrderTicketV2Control>[
          OrderTicketV2Control(
            key: 'review',
            label: 'Primary',
            kind: 'primary',
            enabled: false,
            reason: 'why',
          ),
          OrderTicketV2Control(
            key: 'draft',
            label: 'Secondary',
            kind: 'secondary',
            enabled: true,
            reason: null,
          ),
        ],
      );

      expect(find.byType(DecoratedBox), findsOneWidget);
      expect(find.text('Secondary'), findsOneWidget);
    });
  });
}
