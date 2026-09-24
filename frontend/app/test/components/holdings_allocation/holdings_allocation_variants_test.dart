import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/charts/donut_chart.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_bar.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'holdings_allocation_class_fixture.dart';

void main() {
  group(HoldingsAllocationCard, () {
    testWidgets('the Home variant draws no chrome, a centre and a bar', (
      tester,
    ) async {
      await tester.pumpApp(
        SizedBox(
          width: 390,
          child: HoldingsAllocationCard(
            data: byClass(gain: null, headline: false),
          ),
        ),
      );
      expect(find.text('Holdings & allocation'), findsNothing);
      expect(find.text('Classes'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.byType(HoldingsAllocationBar), findsOneWidget);
      expect(find.text('▲ +0.9%'), findsOneWidget);
      final donut = tester.widget<DonutChart>(find.byType(DonutChart));
      expect(donut.swatches, same(ChartTokens.allocationLight.classSwatches));
      expect(donut.diameter, HoldingsAllocationCard.compactDiameter);
    });

    testWidgets('the catalog variant keeps its header and gain', (
      tester,
    ) async {
      await tester.pumpApp(
        SizedBox(width: 390, child: HoldingsAllocationCard(data: byClass())),
      );
      expect(find.text('Holdings & allocation'), findsOneWidget);
      expect(
        find.text(r'▲ +$61,204 (+14.5%)  all-time', findRichText: true),
        findsOneWidget,
      );
    });
  });
}
