import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_tokens.dart';
import 'package:finance_app/theme/home_palettes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(AttributionWaterfallTokens, () {
    test('carries the values measured from the two design pages', () {
      // The pill: Catalog_AttributionWaterfall, light and dark artboards.
      expect(
        AttributionWaterfallTokens.light.pillGainSurface,
        const Color(0xFFE3F3EC),
      );
      expect(
        AttributionWaterfallTokens.dark.pillGainSurface,
        const Color(0xFF12291F),
      );
      // The selection: the catalog page's light ring, Flow A's D2 dashes.
      expect(
        AttributionWaterfallTokens.light.selection,
        const Color(0xFF4F5DFF),
      );
      expect(
        AttributionWaterfallTokens.dark.selection,
        const Color(0xFFB9C0FF),
      );
    });

    test('agrees with the chart palette and the shell on the shared roles', () {
      // Measured independently and pinned, so the two files cannot drift
      // apart while staying separate (the `taxlot_tokens_test` rule).
      expect(
        AttributionWaterfallTokens.light.selection,
        ChartTokens.light.barTotal,
      );
      expect(
        AttributionWaterfallTokens.dark.selection,
        homeTokensDark.segmentSelected,
      );
      expect(
        AttributionWaterfallTokens.light.selection,
        homeTokensLight.segmentSelected,
      );
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
