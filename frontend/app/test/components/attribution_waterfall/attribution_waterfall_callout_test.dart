import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_callout.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_pointer.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'attribution_waterfall_harness.dart';

/// The desktop presentation of a selection: a floating card above the tapped
/// bar with a pointer aimed at it (spec frontend/0028 AC-3). It prints the
/// same three payload strings as the mobile strip beside it.
void main() {
  group(AttributionWaterfallCallout, () {
    testWidgets('prints the same three strings, stacked, with a pointer', (
      tester,
    ) async {
      await tester.pumpApp(
        SizedBox(
          width: AttributionWaterfallCallout.width,
          child: AttributionWaterfallCallout(
            step: fixtureStep(WaterfallStepKind.gain, detail: '+4.2% · 90 sh'),
            pointerDx: 40,
          ),
        ),
      );
      expect(find.text('NVDA · NVIDIA Corp'), findsOneWidget);
      expect(find.text('+4.2% · 90 sh'), findsOneWidget);
      expect(find.text(r'$10,230.00'), findsOneWidget);
      final pointer = tester.widget<AttributionWaterfallPointer>(
        find.byType(AttributionWaterfallPointer),
      );
      expect(pointer.dx, 40);
    });

    testWidgets('omits the sentence when the payload carries none', (
      tester,
    ) async {
      await tester.pumpApp(
        SizedBox(
          width: AttributionWaterfallCallout.width,
          child: AttributionWaterfallCallout(
            step: fixtureStep(WaterfallStepKind.loss),
            pointerDx: 10,
          ),
        ),
      );
      expect(find.textContaining(' sh'), findsNothing);
      expect(
        tester.widget<Text>(find.text(r'$10,230.00')).style?.color,
        ChartTokens.light.barLoss,
      );
    });

    testWidgets('repaints its pointer only when the aim or the fill moves', (
      tester,
    ) async {
      // The pointer is the one painted piece of the callout, and a
      // `shouldRepaint` that always answered false would leave it aimed at
      // the previously selected bar.
      await tester.pumpApp(
        SizedBox(
          width: AttributionWaterfallCallout.width,
          child: AttributionWaterfallCallout(
            step: fixtureStep(WaterfallStepKind.gain),
            pointerDx: 40,
          ),
        ),
      );
      final painter = tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(AttributionWaterfallPointer),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!;
      expect(painter.shouldRepaint(painter), isFalse);
      await tester.pumpApp(
        SizedBox(
          width: AttributionWaterfallCallout.width,
          child: AttributionWaterfallCallout(
            step: fixtureStep(WaterfallStepKind.gain),
            pointerDx: 90,
          ),
        ),
        brightness: Brightness.dark,
      );
      final moved = tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(AttributionWaterfallPointer),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!;
      expect(moved.shouldRepaint(painter), isTrue);
    });
  });
}
