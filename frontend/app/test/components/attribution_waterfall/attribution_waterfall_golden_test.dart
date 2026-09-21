import 'package:finance_app/charts/waterfall_chart.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_component.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';

/// Goldens for the chart, in both themes and in the selected state.
///
/// They sit **beside** the geometry assertions in `finance_charts`, not
/// instead of them: a golden says something moved, the arithmetic says what.
///
/// **They capture the chart, not the whole card, and that was measured rather
/// than chosen for tidiness.** A raster is not portable — the same tree
/// renders differently on macOS and on the Linux runner — and glyph edges are
/// where nearly all of that difference lives. Whole-card goldens (a title,
/// three chips, an axis row and a detail strip) drifted **0.54–0.70 %** across
/// platforms, while the smallest defect worth catching — one bar drawn in the
/// wrong mark — moves **1.26 %**. A signal-to-noise ratio under two is not a
/// gate anybody should trust, and widening the tolerance to fit it would have
/// been threshold-fitting.
///
/// Goldening the chart alone cuts the text to seven short axis labels and
/// leaves the margin wide. The card's text is asserted by `find.text` in
/// `attribution_waterfall_card_test.dart`, which is a better check for text
/// than a raster, and its chrome constants are asserted as constants.
/// ADR-L D-15 carries the ruling.
void main() {
  group('AttributionWaterfall goldens', () {
    late AttributionWaterfallData data;

    setUp(() {
      data = const AttributionWaterfallComponent().read(
        ViewPayload.fromJson(
          CatalogSnapshot.load().exampleFor('AttributionWaterfall'),
        ),
      );
    });

    /// The chart inside its own repaint boundary.
    ///
    /// Without the boundary `matchesGoldenFile` walks up to the nearest one —
    /// the whole test surface — and silently captures far more than the
    /// finder names, which is what made the first attempt at this suite noisy.
    const boundary = Key('golden-subject');

    Widget subject({int? selected}) => Center(
      child: RepaintBoundary(
        key: boundary,
        child: SizedBox(
          // The design's plot width for a single card at 1024.
          width: 533.37,
          child: WaterfallChart(
            steps: data.waterfallSteps,
            valueLabels: data.valueDisplays,
            axisLabels: data.axisLabels,
            selectedIndex: selected,
          ),
        ),
      ),
    );

    testWidgets('default, light', (tester) async {
      await tester.pumpApp(subject());
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/attribution_waterfall_light.png'),
      );
    });

    testWidgets('default, dark', (tester) async {
      await tester.pumpApp(subject(), brightness: Brightness.dark);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/attribution_waterfall_dark.png'),
      );
    });

    testWidgets('selected, light', (tester) async {
      await tester.pumpApp(subject(selected: 1));
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/attribution_waterfall_selected.png'),
      );
    });
  });
}
