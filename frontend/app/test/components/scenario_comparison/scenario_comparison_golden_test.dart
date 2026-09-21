import 'package:finance_app/components/scenario_comparison/scenario_comparison_header_border.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_layout.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// Goldens for the one thing on this card that is drawn rather than laid
/// out: a column header's open-bottom, round-topped hairline.
///
/// **The golden is this narrow on purpose, and the reasoning is ADR-L D-15
/// applied rather than repeated.** A raster is not portable, and glyph
/// edges are where nearly all the cross-platform difference lives — the
/// measured noise floor is 0.69 % and whole-card goldens drifted 0.54–0.70 %
/// for the waterfall, which already had bars to carry signal. *This* card is
/// text end to end: a golden of it would be almost entirely noise, and the
/// defect most worth catching — a token one step off, `#F0EDF5` against
/// `#F0EEF5` — moves well under 1 % of it. Widening the tolerance to see
/// that would be threshold-fitting; the tolerance stays at 1.5 %.
///
/// So the colours are asserted **directly** instead, against the rendered
/// `BoxDecoration` and the painter's own constants, in
/// `scenario_comparison_tokens_test.dart` and
/// `scenario_comparison_table_test.dart` — which catches a one-step error
/// exactly, where no raster could. What is left for a golden is the
/// *shape*: that the path closes at the top with a 10 px radius and stays
/// open at the bottom. Nothing but a raster proves that, and with no text in
/// the frame it proves it with almost no noise.
void main() {
  group('ScenarioComparison goldens', () {
    const boundary = Key('golden-subject');

    Widget subject() => Center(
      child: RepaintBoundary(
        key: boundary,
        child: Builder(
          builder: (context) => SizedBox(
            // Cropped to just enough frame to show both corners and the
            // open bottom. The width is **not** the design's track width on
            // purpose: the claim is the path's shape, which does not depend
            // on it, and every pixel of empty track is signal thrown away.
            // At the design's 121.28 the radius mutation below moved 1.66 %
            // against a 1.5 % tolerance — a margin of 1.1×, which is not a
            // gate worth trusting. Cropping raised it without touching the
            // threshold, which goes down as the noise is understood and
            // never up to absorb a failure (ADR-L D-15).
            width: 56,
            height: 30,
            child: CustomPaint(
              painter: ScenarioHeaderBorderPainter(
                color: ScenarioComparisonTokens.of(context).headerBorder,
                radius: ScenarioComparisonLayout.headerCellRadius,
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('column header hairline, light', (tester) async {
      await tester.pumpApp(subject());
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/scenario_header_border_light.png'),
      );
    });

    testWidgets('column header hairline, dark', (tester) async {
      await tester.pumpApp(subject(), brightness: Brightness.dark);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/scenario_header_border_dark.png'),
      );
    });
  });
}
