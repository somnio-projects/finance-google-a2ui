import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_pill.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  AttributionNet net(NetDirection direction, String amount, String percent) =>
      AttributionNet(
        label: 'Net',
        amountDisplay: amount,
        percentDisplay: percent,
        direction: direction,
      );

  DecoratedBox box(WidgetTester tester) =>
      tester.widget<DecoratedBox>(find.byType(DecoratedBox));

  group(AttributionWaterfallPill, () {
    testWidgets('draws a gain with the glyph on the measured green fill', (
      tester,
    ) async {
      await tester.pumpApp(
        AttributionWaterfallPill(net: net(NetDirection.up, r'+$3,240', '+1%')),
      );
      final text = tester.widget<Text>(find.text(r'▲ Net +$3,240 (+1%)'));
      expect(text.style?.color, ChartTokens.light.barGain);
      expect(
        (box(tester).decoration as BoxDecoration).color,
        AttributionWaterfallTokens.light.pillGainSurface,
      );
    });

    testWidgets('draws a loss in the loss mark on the neutral fill', (
      tester,
    ) async {
      await tester.pumpApp(
        AttributionWaterfallPill(
          net: net(NetDirection.down, r'-$3,240', '-1%'),
        ),
      );
      final text = tester.widget<Text>(find.text(r'▼ Net -$3,240 (-1%)'));
      expect(text.style?.color, ChartTokens.light.barLoss);
      expect(
        (box(tester).decoration as BoxDecoration).color,
        ChartTokens.light.rule,
      );
    });

    testWidgets('draws a flat walk with no glyph, muted', (tester) async {
      // The backend prints no sign for a flat move; the pill adds none.
      await tester.pumpApp(
        AttributionWaterfallPill(net: net(NetDirection.flat, r'$0.00', '0%')),
      );
      final text = tester.widget<Text>(find.text(r'Net $0.00 (0%)'));
      expect(text.style?.color, ChartTokens.light.mutedLabel);
    });

    testWidgets('takes the dark fill under the dark theme', (tester) async {
      await tester.pumpApp(
        AttributionWaterfallPill(net: net(NetDirection.up, r'+$1', '+1%')),
        brightness: Brightness.dark,
      );
      expect(
        (box(tester).decoration as BoxDecoration).color,
        AttributionWaterfallTokens.dark.pillGainSurface,
      );
      expect(
        tester.widget<Text>(find.text(r'▲ Net +$1 (+1%)')).style?.color,
        ChartTokens.dark.barGain,
      );
    });
  });
}
