import 'package:finance_app/charts/donut_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  group(DonutChart, () {
    /// Four equal quarters, so a tap's expected slice is obvious by eye:
    /// 0 is the top-right quadrant, 1 bottom-right, 2 bottom-left, 3 top-left.
    const quarters = <double>[0.25, 0.25, 0.25, 0.25];

    Future<List<int>> pumpAndTap(
      WidgetTester tester,
      Offset offsetFromCentre,
    ) async {
      final taps = <int>[];
      await tester.pumpApp(
        Center(
          child: DonutChart(weights: quarters, onSliceTap: taps.add),
        ),
      );
      final centre = tester.getCenter(find.byKey(DonutChart.plotKey));
      await tester.tapAt(centre + offsetFromCentre);
      await tester.pump();
      return taps;
    }

    testWidgets('sizes itself to the design diameter by default', (
      tester,
    ) async {
      await tester.pumpApp(const Center(child: DonutChart(weights: quarters)));
      expect(
        tester.getSize(find.byKey(DonutChart.plotKey)),
        const Size(DonutChart.designDiameter, DonutChart.designDiameter),
      );
    });

    testWidgets('resolves a tap in each quadrant to its own slice', (
      tester,
    ) async {
      // Hit testing is by angle, which is what makes a 29 px-thick ring a
      // usable target. Each offset sits well inside one quadrant.
      expect(await pumpAndTap(tester, const Offset(30, -30)), equals(<int>[0]));
      expect(await pumpAndTap(tester, const Offset(30, 30)), equals(<int>[1]));
      expect(await pumpAndTap(tester, const Offset(-30, 30)), equals(<int>[2]));
      expect(
        await pumpAndTap(tester, const Offset(-30, -30)),
        equals(<int>[3]),
      );
    });

    testWidgets('treats a tap in the hole as a tap on that direction', (
      tester,
    ) async {
      // Deliberate: the reader aimed at the slice, not at the ring's pixels.
      expect(await pumpAndTap(tester, const Offset(4, -4)), equals(<int>[0]));
    });

    testWidgets('resolves a tap exactly at the centre without throwing', (
      tester,
    ) async {
      expect(await pumpAndTap(tester, Offset.zero), equals(<int>[1]));
    });

    testWidgets('ignores a tap when nothing is listening', (tester) async {
      await tester.pumpApp(const Center(child: DonutChart(weights: quarters)));
      await tester.tapAt(tester.getCenter(find.byKey(DonutChart.plotKey)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports no slice for an empty portfolio', (tester) async {
      final taps = <int>[];
      await tester.pumpApp(
        Center(
          child: DonutChart(weights: const <double>[], onSliceTap: taps.add),
        ),
      );
      await tester.tapAt(tester.getCenter(find.byKey(DonutChart.plotKey)));
      expect(taps, isEmpty);
    });

    testWidgets('skips a zero-weight slice when resolving a tap', (
      tester,
    ) async {
      final taps = <int>[];
      await tester.pumpApp(
        Center(
          child: DonutChart(
            weights: const <double>[0.5, 0, 0.5],
            onSliceTap: taps.add,
          ),
        ),
      );
      final centre = tester.getCenter(find.byKey(DonutChart.plotKey));
      await tester.tapAt(centre + const Offset(30, 0));
      expect(taps, equals(<int>[0]));
    });
  });
}
