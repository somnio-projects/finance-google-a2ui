import 'package:finance_app/charts/donut_chart.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_card.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_empty.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_legend.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'holdings_allocation_harness.dart';

void main() {
  group(HoldingsAllocationCard, () {
    /// The design's own two widths: the catalog board is 1024 and the card
    /// sits in a 1.55fr column; a phone is 360.
    const desktop = Size(1000, 900);
    const phone = Size(360, 900);

    Widget subject({AllocationData data = twoCategories, int? selected}) =>
        Center(
          child: HoldingsAllocationCard(
            data: data,
            initialSelectedIndex: selected,
          ),
        );

    testWidgets('renders the header the design lays out', (tester) async {
      // AC-1: caption, headline figure, then the total's label — the design's
      // three header lines, filled from the three fields the contract has.
      await tester.pumpApp(subject(), surfaceSize: desktop);
      expect(find.text('Allocation by holding'), findsOneWidget);
      expect(find.text(r'$65,038.60'), findsOneWidget);
      expect(find.text('Total market value'), findsOneWidget);
    });

    testWidgets('renders one legend row per category, residual included', (
      tester,
    ) async {
      // AC-3: the residual bucket is a normal row the backend decided to
      // send; the client neither computes it nor decides when it appears.
      await tester.pumpApp(subject(), surfaceSize: desktop);
      expect(find.text('Bitcoin'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('2.35%'), findsOneWidget);
      expect(find.byType(DonutChart), findsOneWidget);
    });

    testWidgets('states the empty portfolio instead of drawing a ring', (
      tester,
    ) async {
      // AC-4: no donut, nothing thrown, and the title and total still shown —
      // an empty portfolio has a total and it is a real figure.
      await tester.pumpApp(
        subject(
          data: const AllocationData(
            title: 'Allocation by holding',
            totalLabel: 'Total market value',
            totalDisplay: r'$0.00',
            categories: <AllocationCategory>[],
          ),
        ),
        surfaceSize: desktop,
      );
      expect(find.text(HoldingsAllocationEmpty.message), findsOneWidget);
      expect(find.byType(DonutChart), findsNothing);
      expect(find.text(r'$0.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('draws a single holding as one full ring', (tester) async {
      await tester.pumpApp(
        subject(
          data: AllocationData(
            title: 'Allocation by holding',
            totalLabel: 'Total market value',
            totalDisplay: r'$38,550.00',
            categories: <AllocationCategory>[twoCategories.categories.first],
          ),
        ),
        surfaceSize: desktop,
      );
      expect(find.byType(DonutChart), findsOneWidget);
      expect(find.text('Bitcoin'), findsOneWidget);
    });

    testWidgets('lays the ring beside the legend at desktop width', (
      tester,
    ) async {
      // AC-8: the design's primary card — ring left, legend right, 150 px.
      await tester.pumpApp(subject(), surfaceSize: desktop);
      final chart = tester.widget<DonutChart>(find.byType(DonutChart));
      expect(chart.diameter, equals(DonutChart.designDiameter));
      final chartBox = tester.getRect(find.byType(DonutChart));
      final legendBox = tester.getRect(find.byType(HoldingsAllocationLegend));
      expect(chartBox.right, lessThanOrEqualTo(legendBox.left));
      expect(tester.takeException(), isNull);
    });

    testWidgets('stacks the ring above the legend at phone width', (
      tester,
    ) async {
      // AC-8: the design's secondary card — ring centred above, 112 px.
      await tester.pumpApp(subject(), surfaceSize: phone);
      final chart = tester.widget<DonutChart>(find.byType(DonutChart));
      expect(chart.diameter, equals(HoldingsAllocationCard.stackedDiameter));
      final chartBox = tester.getRect(find.byType(DonutChart));
      final legendBox = tester.getRect(find.byType(HoldingsAllocationLegend));
      expect(chartBox.bottom, lessThanOrEqualTo(legendBox.top));
      expect(tester.takeException(), isNull);
    });

    testWidgets('selects a category from its legend row, and clears it', (
      tester,
    ) async {
      await tester.pumpApp(subject(), surfaceSize: desktop);
      await tester.tap(find.text('Bitcoin'));
      await tester.pump();
      expect(_selected(tester), equals(0));
      await tester.tap(find.text('Bitcoin'));
      await tester.pump();
      expect(_selected(tester), isNull);
    });

    testWidgets('starts in the selected state a golden needs', (tester) async {
      await tester.pumpApp(subject(selected: 1), surfaceSize: desktop);
      expect(_selected(tester), equals(1));
    });

    testWidgets('gives a screen reader one label per figure', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(subject(), surfaceSize: desktop);
      expect(
        find.bySemanticsLabel(
          r'Allocation by holding Total market value $65,038.60',
        ),
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

int? _selected(WidgetTester tester) =>
    tester.widget<DonutChart>(find.byType(DonutChart)).selectedIndex;
