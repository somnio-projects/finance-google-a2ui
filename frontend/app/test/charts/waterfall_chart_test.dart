import 'package:finance_app/charts/waterfall_chart.dart';
import 'package:finance_app/charts/waterfall_overlay.dart';
import 'package:finance_app/charts/waterfall_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import 'waterfall_harness.dart';

void main() {
  group(WaterfallChart, () {
    Widget subject({
      void Function(String key)? onSegmentTap,
      WaterfallSelection? selection,
      WaterfallOverlay? overlay,
      double width = 560,
    }) => Center(
      child: SizedBox(
        width: width,
        child: WaterfallChart(
          steps: harnessSteps,
          valueLabels: harnessValueDisplays,
          axisLabels: harnessAxisLabels,
          onSegmentTap: onSegmentTap,
          selection: selection,
          overlay: overlay,
        ),
      ),
    );

    testWidgets('renders one axis label per step, verbatim', (tester) async {
      await tester.pumpApp(subject());
      for (final label in harnessAxisLabels) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('never puts a raw figure on screen', (tester) async {
      // N-4: the levels reached the chart as pixel positions and must not
      // reappear as text anywhere.
      await tester.pumpApp(subject());
      expect(find.textContaining('65038.6'), findsNothing);
      expect(find.textContaining('56925'), findsNothing);
    });

    testWidgets('reports the tapped band by its backend key', (tester) async {
      final tapped = <String>[];
      await tester.pumpApp(subject(onSegmentTap: tapped.add));
      // The plot is 560 wide over seven bands of 80; the second band's
      // centre is at 120 from the chart's left edge.
      final chart = tester.getTopLeft(find.byKey(WaterfallChart.plotKey));
      await tester.tapAt(chart + const Offset(120, 100));
      await tester.pump();
      expect(tapped, <String>['BTC']);
    });

    testWidgets('ignores a tap when nobody is listening', (tester) async {
      await tester.pumpApp(subject());
      final chart = tester.getTopLeft(find.byKey(WaterfallChart.plotKey));
      await tester.tapAt(chart + const Offset(120, 100));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('ignores a tap outside every band', (tester) async {
      final tapped = <String>[];
      await tester.pumpApp(subject(onSegmentTap: tapped.add));
      final chart = tester.getTopLeft(find.byKey(WaterfallChart.plotKey));
      await tester.tapAt(chart + const Offset(-5, 100));
      await tester.pump();
      expect(tapped, isEmpty);
    });

    testWidgets('lays itself out from the width it is given', (tester) async {
      // Responsive through LayoutBuilder and nothing else — no breakpoint.
      await tester.pumpApp(subject(width: 280));
      expect(tester.takeException(), isNull);
      expect(find.text('Bitcoin'), findsOneWidget);
    });
  });
}
