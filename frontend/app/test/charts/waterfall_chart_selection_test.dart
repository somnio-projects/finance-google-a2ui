import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/charts/waterfall_chart.dart';
import 'package:finance_app/charts/waterfall_overlay.dart';
import 'package:finance_app/charts/waterfall_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import 'waterfall_harness.dart';

/// The selected state of the chart, split from the main suite under the
/// 150-line budget: the tint, the two bold names and the floating overlay.
void main() {
  group('WaterfallChart selection', () {
    Widget subject({
      WaterfallSelection? selection,
      WaterfallOverlay? overlay,
    }) => Center(
      child: SizedBox(
        width: 560,
        child: WaterfallChart(
          steps: harnessSteps,
          valueLabels: harnessValueDisplays,
          axisLabels: harnessAxisLabels,
          selection: selection,
          overlay: overlay,
        ),
      ),
    );

    testWidgets('tints the selected band across the plot and its label', (
      tester,
    ) async {
      // The UI Kit's selection is a column, not a ring: it has to be as wide
      // as the band and as tall as the chart, axis row included, or the bold
      // label below it reads as a separate decision (0028 OD-3, AC-2).
      await tester.pumpApp(
        subject(
          selection: const WaterfallSelection(
            index: 1,
            barFill: Color(0xFF0C6349),
            column: Color(0xFFE8FEF3),
          ),
        ),
      );
      final tint = tester.widget<DecoratedBox>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              (widget.decoration as BoxDecoration).color ==
                  const Color(0xFFE8FEF3),
        ),
      );
      expect((tint.decoration as BoxDecoration).color, const Color(0xFFE8FEF3));
      final band = tester.getRect(find.byWidget(tint));
      final chart = tester.getRect(find.byType(WaterfallChart));
      expect(band.width, closeTo(80, 0.01));
      expect(band.left, closeTo(chart.left + 80, 0.01));
      expect(band.height, closeTo(chart.height, 0.01));
    });

    testWidgets('bolds the selected name and the closing total, and nothing '
        'else', (tester) async {
      await tester.pumpApp(
        subject(
          selection: const WaterfallSelection(
            index: 1,
            barFill: Color(0xFF0C6349),
            column: Color(0xFFE8FEF3),
          ),
        ),
      );
      Text label(String text) => tester.widget<Text>(find.text(text));
      expect(label('Bitcoin').style?.color, ChartTokens.light.title);
      expect(label('Market value').style?.color, ChartTokens.light.title);
      expect(label('Solana').style?.color, ChartTokens.light.mutedLabel);
      expect(label('Cost basis').style?.color, ChartTokens.light.mutedLabel);
    });

    testWidgets('floats the overlay above the selected bar and aims it', (
      tester,
    ) async {
      await tester.pumpApp(
        subject(
          selection: const WaterfallSelection(
            index: 1,
            barFill: Color(0xFF0C6349),
            column: Color(0xFFE8FEF3),
          ),
          overlay: WaterfallOverlay(
            width: 232,
            builder: (context, dx) =>
                SizedBox(height: 40, child: Text('at $dx')),
          ),
        ),
      );
      // The second band's bar is centred 120 px in, and a 232-wide callout
      // centred there starts at 4 — inside the plot, so it is not clamped.
      expect(find.text('at 116.0'), findsOneWidget);
      final callout = tester.getRect(find.text('at 116.0'));
      final plot = tester.getRect(find.byKey(WaterfallChart.plotKey));
      expect(callout.bottom, lessThan(plot.bottom));
    });

    testWidgets('draws no overlay while nothing is selected', (tester) async {
      await tester.pumpApp(
        subject(
          overlay: WaterfallOverlay(
            width: 232,
            builder: (context, dx) => const Text('callout'),
          ),
        ),
      );
      expect(find.text('callout'), findsNothing);
    });
  });
}
