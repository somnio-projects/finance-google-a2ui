import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_detail.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_tokens.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'attribution_waterfall_harness.dart';

/// The mobile presentation of a selection: a full-bleed strip under the
/// chart, printing the payload's own three strings (spec frontend/0028 AC-3).
/// Its desktop counterpart is `attribution_waterfall_callout_test.dart`.
void main() {
  group(AttributionWaterfallDetail, () {
    testWidgets('prints the identity, the sentence and the contribution', (
      tester,
    ) async {
      await tester.pumpApp(
        AttributionWaterfallDetail(
          step: fixtureStep(WaterfallStepKind.gain, detail: '+4.2% · 90 sh'),
        ),
      );
      expect(find.text('NVDA · NVIDIA Corp'), findsOneWidget);
      expect(find.text('+4.2% · 90 sh'), findsOneWidget);
      expect(find.text(r'$10,230.00'), findsOneWidget);
    });

    testWidgets('marks a gain and a loss with their own colours', (
      tester,
    ) async {
      await tester.pumpApp(
        AttributionWaterfallDetail(step: fixtureStep(WaterfallStepKind.gain)),
      );
      expect(
        tester.widget<Text>(find.text(r'$10,230.00')).style?.color,
        ChartTokens.light.barGain,
      );
      await tester.pumpApp(
        AttributionWaterfallDetail(step: fixtureStep(WaterfallStepKind.loss)),
      );
      expect(
        tester.widget<Text>(find.text(r'$10,230.00')).style?.color,
        ChartTokens.light.barLoss,
      );
    });

    testWidgets('prints no sentence for a step that has none', (tester) async {
      await tester.pumpApp(
        AttributionWaterfallDetail(step: fixtureStep(WaterfallStepKind.total)),
      );
      expect(find.textContaining(' sh'), findsNothing);
      // A total is its label alone — its key is synthetic.
      expect(find.text('NVIDIA Corp'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(r'$10,230.00')).style?.color,
        ChartTokens.light.mutedLabel,
      );
    });

    testWidgets('sits on the measured footer surface', (tester) async {
      await tester.pumpApp(
        AttributionWaterfallDetail(step: fixtureStep(WaterfallStepKind.gain)),
        brightness: Brightness.dark,
      );
      final strip = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(AttributionWaterfallDetail),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        (strip.decoration as BoxDecoration).color,
        AttributionWaterfallTokens.dark.footerSurface,
      );
    });
  });
}
