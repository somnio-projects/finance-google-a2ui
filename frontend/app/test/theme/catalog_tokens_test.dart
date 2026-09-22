import 'package:finance_app/theme/app_theme.dart';
import 'package:finance_app/theme/catalog_palettes.dart';
import 'package:finance_app/theme/catalog_tokens.dart';
import 'package:finance_app/theme/home_palettes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  group(CatalogTokens, () {
    test('the light palette is the measured light artboard', () {
      // Literals, on purpose: read from the pages' inline styles (0013 §2).
      expect(catalogTokensLight.board, const Color(0xFFF4F2F8));
      expect(catalogTokensLight.topBar, const Color(0xFFFDFBFF));
      expect(catalogTokensLight.accent, const Color(0xFF4F5DFF));
      expect(catalogTokensLight.pill, const Color(0xFFEAE7F5));
      expect(catalogTokensLight.pillText, const Color(0xFF3A2F70));
      expect(catalogTokensLight.componentPill, const Color(0xFFDCEFEC));
      expect(catalogTokensLight.thumbnail, const Color(0xFFF5F3FB));
      expect(catalogTokensLight.badge, const Color(0xFFEFEAF5));
      expect(catalogTokensLight.shortTerm, const Color(0xFFF0A52E));
      expect(catalogTokensLight.longTerm, const Color(0xFF0F9D8F));
      expect(catalogTokensLight.zones.code, const Color(0xFF0D1017));
      expect(catalogTokensLight.zones.codeKey, const Color(0xFF9CDCFE));
      expect(catalogTokensLight.zones.prompt, const Color(0xFFF7F4FC));
      expect(catalogTokensLight.zones.doCard, const Color(0xFFE3F3EC));
      expect(catalogTokensLight.zones.dontText, const Color(0xFF8F2A22));
    });

    test('the dark palette is the measured dark artboard', () {
      expect(catalogTokensDark.board, const Color(0xFF0B0C10));
      expect(catalogTokensDark.card, const Color(0xFF15161C));
      expect(catalogTokensDark.accent, const Color(0xFFB9C0FF));
      expect(catalogTokensDark.tokenSwatch, const Color(0xFF7A83FF));
      expect(catalogTokensDark.componentPillText, const Color(0xFF5FD6C8));
      expect(catalogTokensDark.thumbnail, const Color(0xFF101017));
      expect(catalogTokensDark.shortTerm, const Color(0xFFFFBF5C));
      expect(catalogTokensDark.longTerm, const Color(0xFF3FC8B8));
      expect(catalogTokensDark.zones.code, const Color(0xFF000000));
      expect(catalogTokensDark.zones.codeBorder, const Color(0xFF24252D));
      expect(catalogTokensDark.zones.promptLabel, const Color(0xFFB9A5FF));
      expect(catalogTokensDark.zones.doBadgeText, const Color(0xFF06301F));
      expect(catalogTokensDark.zones.dontStrong, const Color(0xFFFFC9C2));
    });

    test('the legend swatches are the colours the components draw', () {
      // The token legend documents "the color semantics used across every
      // page", so its swatches are pinned to the shell's own gain and loss;
      // a legend that named a palette nothing draws would be a caption lying.
      expect(catalogTokensLight.gain, homeTokensLight.gain);
      expect(catalogTokensLight.loss, homeTokensLight.loss);
      expect(catalogTokensDark.gain, homeTokensDark.gain);
      expect(catalogTokensDark.loss, homeTokensDark.loss);
      expect(catalogTokensLight.card, homeTokensLight.card);
      expect(catalogTokensDark.cardBorder, homeTokensDark.cardBorder);
    });

    test('catalogTokensFor picks the matching palette', () {
      expect(catalogTokensFor(Brightness.light), same(catalogTokensLight));
      expect(catalogTokensFor(Brightness.dark), same(catalogTokensDark));
    });

    test('both real themes carry the tokens', () {
      expect(
        AppTheme.light.extension<CatalogTokens>(),
        same(catalogTokensLight),
      );
      expect(AppTheme.dark.extension<CatalogTokens>(), same(catalogTokensDark));
    });

    test('copyWith and lerp keep the measured values whole', () {
      expect(catalogTokensLight.copyWith(), same(catalogTokensLight));
      expect(
        catalogTokensLight.lerp(catalogTokensDark, 0.2),
        same(catalogTokensLight),
      );
      expect(
        catalogTokensLight.lerp(catalogTokensDark, 0.8),
        same(catalogTokensDark),
      );
      expect(catalogTokensLight.lerp(null, 0.8), same(catalogTokensLight));
    });

    testWidgets('of reads the tokens from the theme in scope', (tester) async {
      late CatalogTokens seen;
      await tester.pumpApp(
        Builder(
          builder: (context) {
            seen = CatalogTokens.of(context);
            return const SizedBox();
          },
        ),
        brightness: Brightness.dark,
      );
      expect(seen, same(catalogTokensDark));
    });
  });
}
