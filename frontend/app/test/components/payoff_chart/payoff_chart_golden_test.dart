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
void main() {
  group('PayoffChart goldens', () {
    const boundary = Key('golden-subject');

    Widget subject() => Center(
      child: RepaintBoundary(
        key: boundary,
        child: SizedBox(
          // The design's plot width for a single card at 1024: `x` 44 → 486.
          width: 442,
          child: PayoffChart(
            series: payoffData().series,
            tickLabels: payoffData().tickLabels,
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
