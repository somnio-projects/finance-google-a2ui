import 'package:finance_app/components/scenario_comparison/scenario_comparison_component.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_table.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_track_row.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scenario_comparison_harness.dart';

/// The widths of one grid row's tracks and gaps, as laid out.
///
/// `.first` is the track row's **own** `Row`, and it has to be said: a
/// winning cell draws a tick beside its figure in a nested `Row`, so a bare
/// descendant finder matches more than one and throws *"too many elements"*
/// rather than failing on geometry.
List<double> _tracks(WidgetTester tester, int index) {
  final row = tester.renderObject<RenderFlex>(
    find
        .descendant(
          of: find.byType(ScenarioTrackRow).at(index),
          matching: find.byType(Row),
        )
        .first,
  );
  return row.getChildrenAsList().map((child) => child.size.width).toList();
}

/// Pixel-perfection, as arithmetic rather than as a raster.
///
/// Every expected number below was read off the designer's rendered DOM
/// with `getComputedStyle` at the 1024 artboard. This is the check a golden
/// cannot be for an all-text card (see `scenario_comparison_golden_test.dart`):
/// a golden says something moved, these say which track.
void main() {
  group('ScenarioComparison geometry', () {
    testWidgets('reproduces the design content box, hairline included', (
      tester,
    ) async {
      // `box-sizing: border-box`: 571.367 outer − 2×1 hairline − 2×18
      // padding = 533.367. Flutter paints a border *over* its child instead
      // of reserving space for it, so this only holds because the card pads
      // by the hairline as well — it read 535.367 before it did, and this
      // assertion is what found that.
      await pumpScenarioCard(tester, scenarioData());
      expect(
        tester.getSize(find.byType(ScenarioComparisonTable)).width,
        closeTo(designContentWidth, 0.01),
      );
    });

    testWidgets('lays the two-scenario grid out as the design measures it', (
      tester,
    ) async {
      final payload = ViewPayload.fromJson(
        withColumnCount(scenarioExample(), 2),
      );
      await pumpScenarioCard(
        tester,
        const ScenarioComparisonComponent().read(payload),
      );
      // DOM: 208.484px 154.438px 154.445px, gap 8px — `1.35fr 1fr 1fr`.
      expect(_tracks(tester, 0), <Matcher>[
        closeTo(208.484, 0.1),
        closeTo(8, 0.001),
        closeTo(154.438, 0.1),
        closeTo(8, 0.001),
        closeTo(154.445, 0.1),
      ]);
    });

    testWidgets('lays the three-scenario grid out as the design measures it', (
      tester,
    ) async {
      await pumpScenarioCard(tester, scenarioData());
      // DOM: 145.531px 121.273px 121.281px 121.281px — `1.2fr 1fr 1fr 1fr`.
      // A single artboard would not have caught a hard-coded ratio.
      expect(_tracks(tester, 0), <Matcher>[
        closeTo(145.531, 0.1),
        closeTo(8, 0.001),
        closeTo(121.273, 0.1),
        closeTo(8, 0.001),
        closeTo(121.281, 0.1),
        closeTo(8, 0.001),
        closeTo(121.281, 0.1),
      ]);
    });

    testWidgets('gives every metric row the header row tracks', (tester) async {
      // The claim the shared `ScenarioTrackRow` exists to make: a figure
      // sits under the header it belongs to. Rows 1 and 4 are the first and
      // last metric rows.
      await pumpScenarioCard(tester, scenarioData());
      expect(_tracks(tester, 1), _tracks(tester, 0));
      expect(_tracks(tester, 4), _tracks(tester, 0));
    });
  });
}
