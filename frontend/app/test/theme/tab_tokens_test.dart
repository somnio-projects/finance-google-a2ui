import 'package:finance_app/theme/activity_tokens.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:finance_app/theme/holdings_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  group(HoldingsTokens, () {
    test('both palettes are the measured artboards', () {
      expect(holdingsTokensLight.toggle, const Color(0xFFEFEAF7));
      expect(holdingsTokensLight.expandedHead, const Color(0xFFF4F2FC));
      expect(holdingsTokensLight.askBorder, const Color(0xFFD9DCFF));
      expect(holdingsTokensDark.toggleSelected, const Color(0xFF3A3556));
      expect(holdingsTokensFor(Brightness.dark), same(holdingsTokensDark));
      expect(
        AppTheme.light.extension<HoldingsTokens>(),
        same(holdingsTokensLight),
      );
      expect(holdingsTokensLight.copyWith(), same(holdingsTokensLight));
      expect(
        holdingsTokensLight.lerp(holdingsTokensDark, 0.2),
        same(holdingsTokensLight),
      );
      expect(
        holdingsTokensLight.lerp(holdingsTokensDark, 0.8),
        same(holdingsTokensDark),
      );
      expect(holdingsTokensLight.lerp(null, 0.8), same(holdingsTokensLight));
    });

    testWidgets('of reads the theme in scope', (tester) async {
      late HoldingsTokens seen;
      await tester.pumpApp(
        Builder(
          builder: (context) {
            seen = HoldingsTokens.of(context);
            return const SizedBox();
          },
        ),
        brightness: Brightness.dark,
      );
      expect(seen, same(holdingsTokensDark));
    });
  });

  group(ActivityTokens, () {
    test("one tile per kind, and the design's two badges", () {
      expect(activityTokensLight.tileFor('buy'), (
        const Color(0xFFEAE7F5),
        const Color(0xFF4A3F8A),
      ));
      expect(activityTokensLight.tileFor('sell').$1, const Color(0xFFF0EEF4));
      expect(
        activityTokensLight.tileFor('dividend').$2,
        const Color(0xFF0C6A52),
      );
      expect(
        activityTokensLight.tileFor('deposit').$1,
        const Color(0xFFE2ECF7),
      );
      expect(
        activityTokensLight.tileFor('other'),
        activityTokensLight.tileFor('buy'),
      );
      expect(activityTokensLight.shortBadge, const Color(0xFFFBE9C8));
      expect(activityTokensLight.longBadge, const Color(0xFFCFE9E3));
      expect(activityTokensDark.dividendGlyph, const Color(0xFF4ADE9E));
      expect(activityTokensFor(Brightness.light), same(activityTokensLight));
      expect(
        AppTheme.dark.extension<ActivityTokens>(),
        same(activityTokensDark),
      );
      expect(activityTokensLight.copyWith(), same(activityTokensLight));
      expect(
        activityTokensLight.lerp(activityTokensDark, 0.2),
        same(activityTokensLight),
      );
      expect(
        activityTokensLight.lerp(activityTokensDark, 0.8),
        same(activityTokensDark),
      );
      expect(activityTokensLight.lerp(null, 0.8), same(activityTokensLight));
    });

    testWidgets('of reads the theme in scope', (tester) async {
      late ActivityTokens seen;
      await tester.pumpApp(
        Builder(
          builder: (context) {
            seen = ActivityTokens.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(seen, same(activityTokensLight));
    });
  });
}
