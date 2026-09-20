import 'package:finance_app/components/holdings_allocation/holdings_allocation_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group(HoldingsAllocationCard, () {
    const rows = <HoldingsAllocationRow>[
      HoldingsAllocationRow(
        categoryKey: 'BTC',
        label: 'Bitcoin',
        valueDisplay: r'$38,550.00',
        weightDisplay: '59.27%',
      ),
      HoldingsAllocationRow(
        categoryKey: 'other',
        label: 'Other',
        valueDisplay: r'$1,527.60',
        weightDisplay: '2.35%',
      ),
    ];

    Widget buildSubject({List<HoldingsAllocationRow> categories = rows}) =>
        HoldingsAllocationCard(
          title: 'Allocation by holding',
          totalLabel: 'Total market value',
          totalDisplay: r'$65,038.60',
          categories: categories,
        );

    testWidgets('renders the title and the total', (tester) async {
      await tester.pumpApp(buildSubject());
      expect(find.text('Allocation by holding'), findsOneWidget);
      expect(find.text('Total market value'), findsOneWidget);
      expect(find.text(r'$65,038.60'), findsOneWidget);
    });

    testWidgets('renders one tile per category, residual bucket included', (
      tester,
    ) async {
      // The residual bucket is a normal row the backend decided to send; the
      // client neither computes it nor decides when it appears.
      await tester.pumpApp(buildSubject());
      expect(find.text('Bitcoin'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('2.35%'), findsOneWidget);
    });

    testWidgets('renders no rows when the backend sent none', (tester) async {
      await tester.pumpApp(
        buildSubject(categories: const <HoldingsAllocationRow>[]),
      );
      expect(find.text('Allocation by holding'), findsOneWidget);
      expect(find.text('Bitcoin'), findsNothing);
    });

    testWidgets('gives a screen reader one label per figure', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(buildSubject());
      expect(
        find.bySemanticsLabel(r'Total market value $65,038.60'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(r'Bitcoin $38,550.00 59.27%'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
