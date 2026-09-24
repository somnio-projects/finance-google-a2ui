import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/components/attribution_driver/attribution_driver_tokens.dart';
import 'package:finance_app/theme/home_palettes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(AttributionDriverTokens, () {
    test("carries the surfaces measured from Flow A's D2 state", () {
      expect(AttributionDriverTokens.dark.card, const Color(0xFF171826));
      expect(AttributionDriverTokens.dark.border, const Color(0xFF33354D));
      expect(AttributionDriverTokens.dark.tile, const Color(0xFF101017));
    });

    test("infers light from the shell's card and the chart's rule", () {
      // Recorded as an inference, not a measurement (spec frontend/0014
      // OD-1): the design exports no light D2 state.
      expect(AttributionDriverTokens.light.card, homeTokensLight.card);
      expect(AttributionDriverTokens.light.border, homeTokensLight.cardBorder);
      expect(AttributionDriverTokens.light.tile, ChartTokens.light.rule);
    });

    test("the ticker chip is the shell's, byte for byte, in dark", () {
      // D2 draws the chip `#232036` on `#c9cbff`, which is exactly what the
      // Home shell measured for its movers tile; the card therefore reads
      // `HomeTokens.ticker` rather than carrying a copy.
      expect(homeTokensDark.ticker, const Color(0xFF232036));
      expect(homeTokensDark.tickerText, const Color(0xFFC9CBFF));
    });

    test('picks a palette by brightness', () {
      expect(
        AttributionDriverTokens.forBrightness(Brightness.light),
        AttributionDriverTokens.light,
      );
      expect(
        AttributionDriverTokens.forBrightness(Brightness.dark),
        AttributionDriverTokens.dark,
      );
    });
  });
}
