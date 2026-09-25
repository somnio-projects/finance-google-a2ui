import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_tokens.dart';
import 'package:finance_app/components/taxlots_table/taxlot_tokens.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The relative luminance of [color], the WCAG definition.
///
/// A literal would pin the hex and say nothing about the *rule*; what the
/// design asks for is a direction — a selected bar is deeper in light and
/// brighter in dark — and that is what survives a palette change.
double _luminance(Color color) => HSLColor.fromColor(color).lightness;

void main() {
  group(AttributionWaterfallTokens, () {
    test('carries the values measured from the UI Kit frame', () {
      expect(
        AttributionWaterfallTokens.light.gainColumn,
        const Color(0xFFE8FEF3),
      );
      expect(
        AttributionWaterfallTokens.light.lossColumn,
        const Color(0xFFFFEDEB),
      );
      expect(
        AttributionWaterfallTokens.dark.gainColumn,
        const Color(0xFF132520),
      );
      expect(
        AttributionWaterfallTokens.light.footerSurface,
        const Color(0xFFF5F3FB),
      );
    });

    test('deepens a selected bar in light and brightens it in dark', () {
      // AC-2, as a direction rather than a hex: transcribing the UI Kit's own
      // selected fill would have made a tapped bar *lighter* than its
      // neighbours, because the frame draws the walk on a lighter base than
      // this app's measured palette (0028 OD-3).
      const light = AttributionWaterfallTokens.light;
      const dark = AttributionWaterfallTokens.dark;
      expect(
        _luminance(light.selectedGainBar),
        lessThan(_luminance(ChartTokens.light.barGain)),
      );
      expect(
        _luminance(light.selectedLossBar),
        lessThan(_luminance(ChartTokens.light.barLoss)),
      );
      expect(
        _luminance(dark.selectedGainBar),
        greaterThan(_luminance(ChartTokens.dark.barGain)),
      );
      expect(
        _luminance(dark.selectedLossBar),
        greaterThan(_luminance(ChartTokens.dark.barLoss)),
      );
    });

    test('keeps a selected bar on the hue its direction earned', () {
      // Selection must never move a bar between the gain and loss families:
      // the colour carries a meaning the payload stated (N-1).
      for (final palette in <AttributionWaterfallPalette>[
        AttributionWaterfallTokens.light,
        AttributionWaterfallTokens.dark,
      ]) {
        expect(
          HSLColor.fromColor(palette.selectedGainBar).hue,
          closeTo(HSLColor.fromColor(palette.gainColumn).hue, 30),
        );
        expect(
          HSLColor.fromColor(palette.selectedLossBar).hue,
          closeTo(HSLColor.fromColor(palette.lossColumn).hue, 30),
        );
      }
    });

    test('agrees with the chart palette and the tax lots on gain and loss', () {
      // AC-5, the `taxlot_tokens_test` idiom: three palettes were measured
      // independently off three pages, and this is what stops them drifting
      // while staying separate files (ADR-L D-3).
      expect(TaxLotTokens.light.gain, ChartTokens.light.barGain);
      expect(TaxLotTokens.light.loss, ChartTokens.light.barLoss);
      expect(TaxLotTokens.dark.gain, ChartTokens.dark.barGain);
      expect(TaxLotTokens.dark.loss, ChartTokens.dark.barLoss);
    });

    test('picks a bar fill and a column by the step kind', () {
      const light = AttributionWaterfallTokens.light;
      expect(
        light.selectedBarFor(WaterfallStepKind.loss),
        light.selectedLossBar,
      );
      expect(
        light.selectedBarFor(WaterfallStepKind.gain),
        light.selectedGainBar,
      );
      expect(light.columnFor(WaterfallStepKind.loss), light.lossColumn);
      expect(light.columnFor(WaterfallStepKind.gain), light.gainColumn);
    });

    test('picks a palette by brightness', () {
      expect(
        AttributionWaterfallTokens.forBrightness(Brightness.light),
        AttributionWaterfallTokens.light,
      );
      expect(
        AttributionWaterfallTokens.forBrightness(Brightness.dark),
        AttributionWaterfallTokens.dark,
      );
    });
  });
}
