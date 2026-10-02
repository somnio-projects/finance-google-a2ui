import 'package:finance_app/charts/waterfall_chart.dart';
import 'package:finance_app/charts/waterfall_selection.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_component.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_skeleton.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';

/// Goldens for the chart and the loading card, in both themes.
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
/// The skeleton is the exception and is goldened whole: it has **no text at
/// all**, so none of that drift applies to it. ADR-L D-15 carries the ruling.
void main() {
  group('AttributionWaterfall goldens', () {
    late AttributionWaterfallData data;

    setUp(() {
      data = const AttributionWaterfallComponent().read(
        ViewPayload.fromJson(
          CatalogSnapshot.load().exampleForView('attribution.waterfall.v1'),
        ),
      );
    });

    /// The subject inside its own repaint boundary.
    ///
    /// Without the boundary `matchesGoldenFile` walks up to the nearest one —
    /// the whole test surface — and silently captures far more than the
    /// finder names, which is what made the first attempt at this suite noisy.
    const boundary = Key('golden-subject');

    Widget framed(Widget child, {double width = 533.37}) => Center(
      child: RepaintBoundary(
        key: boundary,
        // The design's plot width for a single card at 1024.
        child: SizedBox(width: width, child: child),
      ),
    );

    Widget subject({WaterfallSelection? selection}) => framed(
      WaterfallChart(
        steps: data.waterfallSteps,
        valueLabels: data.valueDisplays,
        axisLabels: data.axisLabels,
        selection: selection,
      ),
    );

    WaterfallSelection selected(Brightness brightness) {
      final tokens = AttributionWaterfallTokens.forBrightness(brightness);
      return WaterfallSelection(
        index: 1,
        barFill: tokens.selectedGainBar,
        column: tokens.gainColumn,
      );
    }

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
      await tester.pumpApp(subject(selection: selected(Brightness.light)));
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/attribution_waterfall_selected.png'),
      );
    });

    testWidgets('selected, dark', (tester) async {
      await tester.pumpApp(
        subject(selection: selected(Brightness.dark)),
        brightness: Brightness.dark,
      );
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/attribution_waterfall_selected_dark.png'),
      );
    });

    testWidgets('loading, light', (tester) async {
      await tester.pumpApp(
        framed(const AttributionWaterfallSkeleton(), width: 380),
        reducedMotion: true,
      );
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/attribution_waterfall_loading.png'),
      );
    });

    testWidgets('loading, dark', (tester) async {
      await tester.pumpApp(
        framed(const AttributionWaterfallSkeleton(), width: 380),
        brightness: Brightness.dark,
        reducedMotion: true,
      );
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/attribution_waterfall_loading_dark.png'),
      );
    });
  });
}
