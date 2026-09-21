import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/charts/payoff_palette.dart';
import 'package:finance_app/charts/payoff_tokens.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PayoffTokens', () {
    test("carries the design's measured light values", () {
      // Read from the design's own SVG template, where each is a literal
      // attribute: stroke="#c07a10", stroke="#b8bcc6", fill="#9a9ba4".
      expect(PayoffTokens.light.breakEven, const Color(0xFFC07A10));
      expect(PayoffTokens.light.zeroBaseline, const Color(0xFFB8BCC6));
      expect(PayoffTokens.light.axisLabel, const Color(0xFF9A9BA4));
    });

    test("carries the design's measured dark values", () {
      expect(PayoffTokens.dark.breakEven, const Color(0xFFFFBF5C));
      expect(PayoffTokens.dark.zeroBaseline, const Color(0xFF3A3B44));
      expect(PayoffTokens.dark.axisLabel, const Color(0xFF7F828C));
    });

    test('tints each region at the alpha its own theme uses', () {
      // The design shades at opacity .07 in light and .10 in dark — the one
      // value that is *not* shared between the artboards, which is why the
      // tint is a token rather than an alpha applied at the point of use.
      expect(PayoffTokens.light.lossRegion.a, closeTo(0.07, 1e-6));
      expect(PayoffTokens.light.gainRegion.a, closeTo(0.07, 1e-6));
      expect(PayoffTokens.dark.lossRegion.a, closeTo(0.10, 1e-6));
      expect(PayoffTokens.dark.gainRegion.a, closeTo(0.10, 1e-6));
    });

    test("tints the regions in the chart palette's own marks", () {
      // The defect this catches: the tints were once transcribed hex literals
      // that happened to agree with `barLoss`/`barGain`. Nothing held them
      // together, so recolouring a bar left the wash on the old hue with a
      // green gate. Asserted on the colour channels, since only the alpha
      // may differ.
      void sameHue(Color tint, Color source) {
        expect(tint.r, source.r);
        expect(tint.g, source.g);
        expect(tint.b, source.b);
      }

      sameHue(PayoffTokens.light.lossRegion, ChartTokens.light.barLoss);
      sameHue(PayoffTokens.light.gainRegion, ChartTokens.light.barGain);
      sameHue(PayoffTokens.dark.lossRegion, ChartTokens.dark.barLoss);
      sameHue(PayoffTokens.dark.gainRegion, ChartTokens.dark.barGain);
    });

    test('answers a different palette per brightness', () {
      expect(PayoffTokens.forBrightness(Brightness.light), PayoffTokens.light);
      expect(PayoffTokens.forBrightness(Brightness.dark), PayoffTokens.dark);
    });
  });

  group('PayoffPalette', () {
    test('is carried by both real themes', () {
      expect(AppTheme.light.extension<PayoffPalette>(), PayoffTokens.light);
      expect(AppTheme.dark.extension<PayoffPalette>(), PayoffTokens.dark);
    });

    testWidgets('is read from the context', (tester) async {
      late PayoffPalette read;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              read = PayoffPalette.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(read, PayoffTokens.light);
    });

    test('compares by value', () {
      expect(PayoffTokens.light, PayoffTokens.light.copyWith());
      expect(
        PayoffTokens.light.hashCode,
        PayoffTokens.light.copyWith().hashCode,
      );
      expect(PayoffTokens.light, isNot(PayoffTokens.dark));
    });

    test('copyWith replaces only what it is given', () {
      const replacement = Color(0xFF00FF00);
      expect(
        PayoffTokens.light.copyWith(breakEven: replacement).breakEven,
        replacement,
      );
      expect(
        PayoffTokens.light.copyWith(zeroBaseline: replacement).zeroBaseline,
        replacement,
      );
      expect(
        PayoffTokens.light.copyWith(axisLabel: replacement).axisLabel,
        replacement,
      );
      expect(
        PayoffTokens.light.copyWith(lossRegion: replacement).lossRegion,
        replacement,
      );
      expect(
        PayoffTokens.light.copyWith(gainRegion: replacement).gainRegion,
        replacement,
      );
    });

    test('lerps to the other palette and back', () {
      expect(PayoffTokens.light.lerp(PayoffTokens.dark, 0), PayoffTokens.light);
      expect(PayoffTokens.light.lerp(PayoffTokens.dark, 1), PayoffTokens.dark);
      expect(PayoffTokens.light.lerp(null, 0.5), PayoffTokens.light);
    });

    test('lerps each role independently', () {
      final mid = PayoffTokens.light.lerp(PayoffTokens.dark, 0.5);
      expect(mid.breakEven, isNot(PayoffTokens.light.breakEven));
      expect(mid.zeroBaseline, isNot(PayoffTokens.light.zeroBaseline));
      expect(mid.axisLabel, isNot(PayoffTokens.light.axisLabel));
      expect(mid.lossRegion, isNot(PayoffTokens.light.lossRegion));
      expect(mid.gainRegion, isNot(PayoffTokens.light.gainRegion));
    });
  });
}
