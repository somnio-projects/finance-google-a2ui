import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_card.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_component.dart';
import 'package:finance_app/components/surface_edits.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'order_ticket_v2_harness.dart';

/// GGU-113, the multi-leg ticket: live inside a `SurfaceEdits` scope, as the
/// v1 ticket is, and through the one option it declares.
void main() {
  group('$OrderTicketV2Component inside a SurfaceEdits scope', () {
    const component = OrderTicketV2Component();

    Widget subject({
      required void Function(String option, String value) onOptionChanged,
      String? pendingOption,
      String? rejection,
    }) => Scaffold(
      body: SingleChildScrollView(
        child: SurfaceEdits(
          onOptionChanged: onOptionChanged,
          pendingOption: pendingOption,
          rejection: rejection,
          child: Builder(
            builder: (context) => component.build(
              context,
              ViewPayload.fromJson(ticketV2Example()),
            ),
          ),
        ),
      ),
    );

    testWidgets('a legs change travels as the declared `legs` option', (
      tester,
    ) async {
      final edits = <(String, String)>[];
      await tester.pumpApp(
        subject(onOptionChanged: (option, value) => edits.add((option, value))),
        surfaceSize: const Size(800, 1600),
      );
      final card = tester.widget<OrderTicketV2Card>(
        find.byType(OrderTicketV2Card),
      );
      expect(card.onLegsChanged, isNotNull);
      expect(card.isBusy, isFalse);

      card.onLegsChanged!('3');
      expect(edits, <(String, String)>[
        (OrderTicketV2Component.legsOption, '3'),
      ]);
    });

    testWidgets("draws the host's answer", (tester) async {
      await tester.pumpApp(
        subject(
          onOptionChanged: (_, _) {},
          pendingOption: OrderTicketV2Component.legsOption,
          rejection: 'legs must be between 1 and 4',
        ),
        surfaceSize: const Size(800, 1600),
      );
      final card = tester.widget<OrderTicketV2Card>(
        find.byType(OrderTicketV2Card),
      );
      expect(card.isBusy, isTrue);
      expect(card.rejection, 'legs must be between 1 and 4');
    });
  });
}
