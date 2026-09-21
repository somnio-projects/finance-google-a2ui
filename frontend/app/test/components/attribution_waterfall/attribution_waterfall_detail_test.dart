import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_detail.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  AttributionStep step(WaterfallStepKind kind) => AttributionStep(
    step: WaterfallStep(key: 'k', kind: kind, level: 1),
    label: 'Bitcoin',
    valueDisplay: r'$10,230.00',
    cumulativeDisplay: r'$67,155.00',
  );

  group(AttributionWaterfallHeader, () {
    testWidgets('renders every annotation as one chip, label and text', (
      tester,
    ) async {
      await tester.pumpApp(
        const AttributionWaterfallHeader(
          title: 'Unrealised P/L attribution',
          annotations: <AttributionAnnotation>[
            AttributionAnnotation(label: 'Bitcoin', text: r'$10,230.00'),
            AttributionAnnotation(label: 'Net', text: r'$8,113.60'),
          ],
        ),
      );
      expect(find.text('Unrealised P/L attribution'), findsOneWidget);
      expect(find.text(r'Bitcoin $10,230.00'), findsOneWidget);
      expect(find.text(r'Net $8,113.60'), findsOneWidget);
    });

    testWidgets('renders a title with no annotations at all', (tester) async {
      // `annotations` defaults to `[]` in the contract.
      await tester.pumpApp(
        const AttributionWaterfallHeader(
          title: 'Nothing moved',
          annotations: <AttributionAnnotation>[],
        ),
      );
      expect(find.text('Nothing moved'), findsOneWidget);
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
