import 'package:finance_app/charts/chart_palette.dart';
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

    // The design's plot width for a single card at 1024: `x` 44 → 486.
    const width = 442.0;

    /// How much of the plot's own height is cropped away, top and bottom.
    ///
    /// **The subject is text-free, and that is the whole reason for a crop.**
    /// The redesign put four kinds of label on this chart — the rung ladder,
    /// the break-even's caption, and *Loss* and *Gain* in the two corners —
    /// and glyph edges are the high-amplitude, few-pixel noise ADR-L D-15
    /// calibrated the 1.5 % tolerance *against*, on a subject that had almost
    /// none. Measured: the whole chart differs by **1.545 %** between this
    /// machine and the Linux runner, at a largest channel delta of 163/255,
    /// **identically in both themes** — the signature of glyph rasterisation
    /// rather than of colour.
    ///
    /// The threshold goes down, never up to absorb a failure
    /// (`frontend/testing.md` §6), so the *subject* shrinks instead. What is
    /// left is every claim a raster is the right check for: which side of the
    /// break-even each wash is on, that the rule is dashed, the curve's
    /// colour, and the dot. The labels' **positions** are asserted as
    /// geometry in `payoff_chart_gutter_test.dart`, which is a stronger check
    /// than a raster anyway — it is what would have caught the gutter being
    /// counted twice, where a regenerated golden simply froze it.
    const crop = 26.0;

    /// How much is cropped from the left: past the gutter, so the rung
    /// labels are outside the subject too. **Not derived from the gutter**,
    /// which is measured at run time from the widest label the payload sent
    /// — a crop computed from a layout value is the thing that looks like
    /// proof and is not. Two attempts failed a pixel census of the committed
    /// PNG before this one: cropping only vertically left 2 255 px of label
    /// ink, and cropping 64 left still left a 16 px column of it.
    const cropLeft = 96.0;

    Widget subject() => Center(
      child: RepaintBoundary(
        key: boundary,
        child: SizedBox(
          width: width - cropLeft,
          height: PayoffChart.plotHeight - crop * 2,
          child: Builder(
            builder: (context) {
              final data = payoffData();
              // The washes are translucent, so what is behind them is part of
              // what the golden asserts. Stated here rather than inherited
              // from an ancestor: captured over nothing, a 7 % wash comes
              // back as its unpremultiplied saturated colour and the raster
              // stops resembling the card at all.
              return ColoredBox(
                color: ChartPalette.of(context).surface,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    maxWidth: double.infinity,
                    maxHeight: double.infinity,
                    child: Transform.translate(
                      offset: const Offset(
                        -cropLeft,
                        -PayoffChart.topBand - crop,
                      ),
                      child: SizedBox(
                        width: width,
                        child: PayoffChart(
                          series: data.series,
                          tickLabels: data.tickLabels,
                          valueLabels: <String>[
                            for (final rung in data.rungs) rung.display,
                          ],
                          valueTicks: <double>[
                            for (final rung in data.rungs) rung.at,
                          ],
                          breakEvenAt: data.breakEven?.at,
                          currentAt: data.current?.at,
                          breakEvenLabel: data.breakEven?.caption ?? '',
                          lossWord: data.lossWord,
                          gainWord: data.gainWord,
                        ),
                      ),
                    ),
                  ),
                ),
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
