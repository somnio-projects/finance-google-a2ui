import 'dart:ui' show Tristate;

import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_legend.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'holdings_allocation_harness.dart';

void main() {
  group(HoldingsAllocationLegend, () {
    testWidgets("draws the design's metrics", (tester) async {
      await tester.pumpApp(
        HoldingsAllocationLegend(categories: twoCategories.categories),
        surfaceSize: const Size(600, 400),
      );
      // Measured from the rendered page: a 10 px swatch at a 3 px radius.
      // Asserted as constants because a sub-pixel box is below what a
      // cross-platform raster can resolve (ADR-L D-15's limit).
      expect(HoldingsAllocationLegend.swatchSize, equals(10));
      expect(HoldingsAllocationLegend.swatchRadius, equals(3));
      expect(HoldingsAllocationLegend.rowPadding, equals(6));
      expect(HoldingsAllocationLegend.columnGap, equals(10));
      expect(find.text('Bitcoin'), findsOneWidget);
      expect(find.text(r'$38,550.00'), findsOneWidget);
    });

    testWidgets('colours every category when the ramp runs out', (
      tester,
    ) async {
      // AC-2: `top_n` reaches 20 and `include_other` adds a row, so a payload
      // can outrun the design's six hues. Every row must still be drawn.
      final categories = manyCategories(14);
      await tester.pumpApp(
        HoldingsAllocationLegend(categories: categories),
        surfaceSize: const Size(600, 900),
      );
      for (final category in categories) {
        expect(find.text(category.label), findsOneWidget);
      }
      const ramp = ChartTokens.allocationLight;
      expect(ramp.swatchFor(0), equals(ramp.swatches.first));
      expect(ramp.swatchFor(6), equals(ramp.swatches.first));
      expect(ramp.swatchFor(13), equals(ramp.swatches[1]));
    });

    testWidgets('reports a tap with the row index', (tester) async {
      final tapped = <int>[];
      await tester.pumpApp(
        HoldingsAllocationLegend(
          categories: twoCategories.categories,
          onCategoryTap: tapped.add,
        ),
        surfaceSize: const Size(600, 400),
      );
      await tester.tap(find.text('Other'));
      expect(tapped, equals(<int>[1]));
    });

    testWidgets('ignores a tap when nothing is listening', (tester) async {
      await tester.pumpApp(
        HoldingsAllocationLegend(categories: twoCategories.categories),
        surfaceSize: const Size(600, 400),
      );
      await tester.tap(find.text('Other'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('marks the selected row for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        HoldingsAllocationLegend(
          categories: twoCategories.categories,
          selectedIndex: 0,
        ),
        surfaceSize: const Size(600, 400),
      );
      final node = tester.getSemantics(
        find.bySemanticsLabel(r'Bitcoin $38,550.00 59.27%'),
      );
      expect(node.flagsCollection.isSelected, equals(Tristate.isTrue));
      handle.dispose();
    });

    testWidgets('renders nothing for no categories', (tester) async {
      await tester.pumpApp(
        const HoldingsAllocationLegend(categories: <AllocationCategory>[]),
        surfaceSize: const Size(600, 400),
      );
      expect(find.byType(Text), findsNothing);
    });
  });
}
