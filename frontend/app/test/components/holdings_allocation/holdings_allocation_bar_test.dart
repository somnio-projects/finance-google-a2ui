import 'package:finance_app/charts/allocation_palette.dart';
import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_bar.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_center.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group(HoldingsAllocationBar, () {
    const ramp = <Color>[Color(0xFF111111), Color(0xFF222222)];

    testWidgets('is 6px tall and hands the painter the weights and ramp', (
      tester,
    ) async {
      await tester.pumpApp(
        const Center(
          child: SizedBox(
            width: 300,
            child: HoldingsAllocationBar(
              weights: <double>[0.75, 0, 0.25],
              colors: ramp,
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(HoldingsAllocationBar)).height, 6);
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(HoldingsAllocationBar),
          matching: find.byType(CustomPaint),
        ),
      );
      final painter = paint.painter! as AllocationBarPainter;
      expect(painter.weights, <double>[0.75, 0, 0.25]);
      expect(painter.colors, same(ramp));
      expect(tester.takeException(), isNull);
    });

    test('repaints only when the weights or the ramp change', () {
      const painter = AllocationBarPainter(
        weights: <double>[0.5, 0.5],
        colors: ramp,
      );
      expect(
        painter.shouldRepaint(
          const AllocationBarPainter(weights: <double>[0.5, 0.5], colors: ramp),
        ),
        isFalse,
      );
      expect(
        painter.shouldRepaint(
          const AllocationBarPainter(weights: <double>[1], colors: ramp),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          const AllocationBarPainter(
            weights: <double>[0.5, 0.5],
            colors: <Color>[Color(0xFF333333)],
          ),
        ),
        isTrue,
      );
    });
  });

  group(HoldingsAllocationCenter, () {
    testWidgets('prints unit over count and nothing for no count', (
      tester,
    ) async {
      await tester.pumpApp(
        const Column(
          children: <Widget>[
            HoldingsAllocationCenter(count: '4', unit: 'Classes'),
            HoldingsAllocationCenter(count: '', unit: 'Classes'),
          ],
        ),
      );
      expect(find.text('Classes'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });
  });
  group(AllocationPalette, () {
    test('the class ramp is used for asset_class alone, grey for cash', () {
      final ramp = ChartTokens.allocationLight.rampFor('asset_class');
      expect(ramp, same(ChartTokens.allocationLight.classSwatches));
      expect(ramp[2], const Color(0xFF9AA0AA));
      expect(
        ChartTokens.allocationLight.rampFor('holding'),
        same(ChartTokens.allocationLight.swatches),
      );
      const bare = AllocationPalette(
        swatches: <Color>[Color(0xFF000000)],
        legendWeight: Color(0xFF000000),
        legendValue: Color(0xFF000000),
        legendDivider: Color(0xFF000000),
      );
      expect(bare.rampFor('asset_class'), same(bare.swatches));
    });
  });
}
