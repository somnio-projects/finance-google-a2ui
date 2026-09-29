import 'package:finance_app/charts/payoff_palette.dart';
import 'package:finance_app/charts/payoff_tokens.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PayoffTokens', () {
    test("carries the design's measured light values", () {
      // Read through the Figma inspector from `Risk Payoff Chart /
      // Comparison, Light, Desktop`, node by node (GGU-146). Every one of
      // these was different before, and every previous value came from the
      // catalog mock this repository generated.
      expect(PayoffTokens.light.breakEven, const Color(0xFFCBCDD0));
      expect(PayoffTokens.light.axisLabel, const Color(0xFF56575B));
      expect(PayoffTokens.light.series, const Color(0xFF5498E5));
      expect(PayoffTokens.light.marker, const Color(0xFF3C90F1));
      expect(PayoffTokens.light.markerHalo, const Color(0xFFFFFFFF));
    });

    test("carries the design's measured dark values", () {
      expect(PayoffTokens.dark.breakEven, const Color(0xFF474D58));
      expect(PayoffTokens.dark.axisLabel, const Color(0xFFB9BEC6));
      expect(PayoffTokens.dark.series, const Color(0xFF1763BA));
      expect(PayoffTokens.dark.marker, const Color(0xFF308CF5));
      expect(PayoffTokens.dark.markerHalo, const Color(0xFF17181C));
    });

    test('washes both regions at the one opacity the artboards share', () {
      // The mock had .07 in light and .10 in dark and made a whole argument
      // out of the difference. The kit changes the **token** between themes
      // and leaves the opacity alone — so the interesting assertion is that
      // the four alphas agree, which is what the old values could not do.
      for (final wash in <Color>[
        PayoffTokens.light.lossRegion,
        PayoffTokens.light.gainRegion,
        PayoffTokens.dark.lossRegion,
        PayoffTokens.dark.gainRegion,
      ]) {
        expect(wash.a, closeTo(PayoffTokens.wash, 1e-6));
      }
    });

    test('the second series is the same colour in both themes', () {
      // Not a copy-paste: it is a raw hex in the kit, bound to no token and
      // identical on both artboards, which is Miriam's own open note about
      // the categorical palette showing up in the code. Asserted so that a
      // later pass giving it a token is a red test rather than a surprise.
      expect(PayoffTokens.light.seriesAlt, PayoffTokens.dark.seriesAlt);
      expect(PayoffTokens.light.series, isNot(PayoffTokens.dark.series));
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
      expect(
        PayoffTokens.light.copyWith(series: replacement).series,
        replacement,
      );
      expect(
        PayoffTokens.light.copyWith(seriesAlt: replacement).seriesAlt,
        replacement,
      );
      expect(
        PayoffTokens.light.copyWith(marker: replacement).marker,
        replacement,
      );
      expect(
        PayoffTokens.light.copyWith(markerHalo: replacement).markerHalo,
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
      expect(mid.series, isNot(PayoffTokens.light.series));
      expect(mid.marker, isNot(PayoffTokens.light.marker));
      expect(mid.markerHalo, isNot(PayoffTokens.light.markerHalo));
    });
  });
}
