import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_detail.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_pill.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_tokens.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  AttributionStep step(WaterfallStepKind kind, {String? detail}) =>
      AttributionStep(
        step: WaterfallStep(key: 'k', kind: kind, level: 1),
        label: 'Bitcoin',
        valueDisplay: r'$10,230.00',
        cumulativeDisplay: r'$67,155.00',
        detail: detail,
      );
  const net = AttributionNet(
    label: 'Net',
    amountDisplay: r'+$8,113.60',
    percentDisplay: '+13.74%',
    direction: NetDirection.up,
  );

  group(AttributionWaterfallHeader, () {
    testWidgets('shows the title and the headline pill when nothing is '
        'selected', (tester) async {
      await tester.pumpApp(
        const AttributionWaterfallHeader(
          title: 'Unrealised P/L attribution',
          net: net,
        ),
      );
      expect(find.text('Unrealised P/L attribution'), findsOneWidget);
      expect(find.byType(AttributionWaterfallPill), findsOneWidget);
      expect(find.text(r'▲ Net +$8,113.60 (+13.74%)'), findsOneWidget);
    });

    testWidgets('swaps the pill for the selected caption, verbatim', (
      tester,
    ) async {
      // Flow A's D2 state: `NVDA selected` where the pill was (GGU-100 AC-3).
      await tester.pumpApp(
        const AttributionWaterfallHeader(
          title: 'Unrealised P/L attribution',
          net: net,
          selectedLabel: 'NVDA selected',
        ),
      );
      expect(find.byType(AttributionWaterfallPill), findsNothing);
      final caption = tester.widget<Text>(find.text('NVDA selected'));
      expect(caption.style?.color, AttributionWaterfallTokens.light.selection);
    });
  });

  group(AttributionWaterfallDetail, () {
    testWidgets('shows the label and both figures, verbatim', (tester) async {
      await tester.pumpApp(
        AttributionWaterfallDetail(step: step(WaterfallStepKind.gain)),
      );
      expect(find.text('Bitcoin'), findsOneWidget);
      expect(find.text(r'$10,230.00'), findsOneWidget);
      expect(find.text(r'$67,155.00'), findsOneWidget);
    });

    testWidgets('prints the written detail under the label, and nothing '
        'for a total', (tester) async {
      await tester.pumpApp(
        AttributionWaterfallDetail(
          step: step(WaterfallStepKind.gain, detail: r'+45.72% · 90 sh · $1'),
        ),
      );
      final detail = tester.widget<Text>(find.text(r'+45.72% · 90 sh · $1'));
      expect(detail.style?.color, AttributionWaterfallTokens.light.selection);
      await tester.pumpApp(
        AttributionWaterfallDetail(step: step(WaterfallStepKind.total)),
      );
      expect(find.textContaining(' sh · '), findsNothing);
    });

    testWidgets('marks a gain and a loss with their own colours', (
      tester,
    ) async {
      await tester.pumpApp(
        AttributionWaterfallDetail(step: step(WaterfallStepKind.gain)),
      );
      expect(
        tester.widget<Text>(find.text(r'$10,230.00')).style?.color,
        ChartTokens.light.barGain,
      );
      await tester.pumpApp(
        AttributionWaterfallDetail(step: step(WaterfallStepKind.loss)),
      );
      expect(
        tester.widget<Text>(find.text(r'$10,230.00')).style?.color,
        ChartTokens.light.barLoss,
      );
    });

    testWidgets('leaves a total neutral, because it is not a contribution', (
      tester,
    ) async {
      // The card never selects a total — neither endpoint has a `key` to
      // drill into — but the widget is given a step, and a step has four
      // kinds. Colouring a running total as though it were a gain would be
      // the client asserting a direction the payload never stated.
      for (final kind in <WaterfallStepKind>[
        WaterfallStepKind.start,
        WaterfallStepKind.total,
      ]) {
        await tester.pumpApp(AttributionWaterfallDetail(step: step(kind)));
        expect(
          tester.widget<Text>(find.text(r'$10,230.00')).style?.color,
          ChartTokens.light.mutedLabel,
        );
      }
    });
  });
}
