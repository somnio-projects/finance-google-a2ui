import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_tokens.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_weight_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group(OrderTicketV2WeightBar, () {
    testWidgets('clamps an out-of-range fraction to the track', (tester) async {
      // Geometry only: a fraction past 1 cannot draw past the track, and the
      // figure beside it is still the backend's string.
      await tester.pumpApp(
        const Scaffold(
          body: OrderTicketV2WeightBar(
            fraction: 1.5,
            display: '150.00%',
            isChanged: false,
            ringColor: Colors.white,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('150.00%'), findsOneWidget);
    });
  });

  group('the fill', () {
    testWidgets('takes the indigo when the weight changed', (tester) async {
      await tester.pumpApp(
        const Scaffold(
          body: OrderTicketV2WeightBar(
            fraction: 0.4,
            display: '40.00%',
            isChanged: true,
            ringColor: Colors.white,
          ),
        ),
      );
      final label = tester.widget<Text>(find.text('40.00%'));
      expect(label.style?.color, OrderTicketV2Tokens.light.changed);
    });
  });
}
