import 'package:finance_app/theme/app_theme.dart';
import 'package:finance_app/theme/home_palettes.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  group(HomeTokens, () {
    test('the light palette is the measured light artboard', () {
      // Literals, on purpose: read with getComputedStyle (spec 0026 §2).
      expect(homeTokensLight.page, const Color(0xFFF7F6FB));
      expect(homeTokensLight.card, const Color(0xFFFDFBFF));
      expect(homeTokensLight.badge, const Color(0xFFEAE7F5));
      expect(homeTokensLight.badgeText, const Color(0xFF4A3F8A));
      expect(homeTokensLight.navPill, const Color(0xFFDCD8F2));
      expect(homeTokensLight.segmentSelected, const Color(0xFF4F5DFF));
      expect(homeTokensLight.gain, const Color(0xFF12805C));
    });

    test('the dark palette is the measured dark artboard', () {
      expect(homeTokensDark.page, const Color(0xFF0B0C10));
      expect(homeTokensDark.card, const Color(0xFF15161C));
      // The one colour the earlier audit found missing has a home here.
      expect(homeTokensDark.badgeDot, const Color(0xFFB9C0FF));
      expect(homeTokensDark.segmentSelected, const Color(0xFFB9C0FF));
      expect(homeTokensDark.gain, const Color(0xFF4ADE9E));
    });

    test('forBrightness picks the matching palette', () {
      expect(homeTokensFor(Brightness.light), same(homeTokensLight));
      expect(homeTokensFor(Brightness.dark), same(homeTokensDark));
    });

    test('both real themes carry the tokens', () {
      expect(AppTheme.light.extension<HomeTokens>(), same(homeTokensLight));
      expect(AppTheme.dark.extension<HomeTokens>(), same(homeTokensDark));
    });

    test('copyWith and lerp keep the measured values whole', () {
      expect(homeTokensLight.copyWith(), same(homeTokensLight));
      expect(homeTokensLight.lerp(homeTokensDark, 0.2), same(homeTokensLight));
      expect(homeTokensLight.lerp(homeTokensDark, 0.8), same(homeTokensDark));
      expect(homeTokensLight.lerp(null, 0.8), same(homeTokensLight));
    });

    testWidgets('of reads the tokens from the theme in scope', (tester) async {
      late HomeTokens seen;
      await tester.pumpApp(
        Builder(
          builder: (context) {
            seen = HomeTokens.of(context);
            return const SizedBox();
          },
        ),
        brightness: Brightness.dark,
      );
      expect(seen, same(homeTokensDark));
    });
  });
}
