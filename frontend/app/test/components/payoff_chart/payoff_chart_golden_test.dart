import 'package:finance_app/charts/payoff_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'payoff_chart_harness.dart';

/// Goldens for the payoff plot, in both themes.
///
/// They sit **beside** the arithmetic in `finance_charts`, not instead of it:
/// the geometry suite says which coordinate moved, a golden says only that
/// something did — but it is the only check that catches a colour from the
/// wrong palette, a missing tick row, or a region shaded on the wrong side of
/// zero.
///
/// The subject is the chart alone, not the whole card, for the reason ADR-L
/// D-15 records: glyph edges carry nearly all the cross-platform raster
/// drift, and a card with three totals, four annotations and a four-line
/// disclosure would push the noise floor towards the 1.5 % tolerance.
///
/// **It binds the whole payload, not two fields of it.** Until GGU-146 it
/// passed only `series` and `tickLabels`, so when the design's markers, rungs
/// and region words arrived the goldens re-rendered **identically** and said
/// nothing — a golden over a subject built from part of the model proves the
/// part, and its silence reads exactly like a pass.
void main() {
  group('PayoffChart goldens', () {
    const boundary = Key('golden-subject');

    Widget subject() => Center(
      child: RepaintBoundary(
        key: boundary,
        child: SizedBox(
          // The design's plot width for a single card at 1024: `x` 44 → 486.
          width: 442,
          child: Builder(
            builder: (context) {
              final data = payoffData();
              return PayoffChart(
                series: data.series,
                tickLabels: data.tickLabels,
                valueLabels: <String>[
                  for (final rung in data.rungs) rung.display,
                ],
                valueTicks: <double>[for (final rung in data.rungs) rung.at],
                breakEvenAt: data.breakEven?.at,
                currentAt: data.current?.at,
                breakEvenLabel: data.breakEven?.caption ?? '',
                lossWord: data.lossWord,
                gainWord: data.gainWord,
              );
            },
          ),
        ),
      ),
    );

    testWidgets('default, light', (tester) async {
      await tester.pumpApp(subject());
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/payoff_chart_light.png'),
      );
    });

    testWidgets('default, dark', (tester) async {
      await tester.pumpApp(subject(), brightness: Brightness.dark);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/payoff_chart_dark.png'),
      );
    });
  });
}
