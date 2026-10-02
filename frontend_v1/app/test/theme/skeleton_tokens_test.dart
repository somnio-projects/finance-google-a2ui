import 'package:finance_app/theme/app_theme.dart';
import 'package:finance_app/theme/skeleton_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  group(SkeletonTokens, () {
    test('the light palette is the measured light artboards', () {
      // Literals, on purpose: `.sk`, `.skel` and `.shimL` read off the
      // catalog pages' stylesheets (spec frontend/0015 §2).
      expect(skeletonTokensLight.shimmerBase, const Color(0xFFECE8F2));
      expect(skeletonTokensLight.shimmerHighlight, const Color(0xFFF7F4FB));
      expect(skeletonTokensLight.bar, const Color(0xFFE6E2EF));
      expect(skeletonTokensLight.pill, const Color(0xFFEEF0F2));
      expect(skeletonTokensLight.caption, const Color(0xFF8A8D96));
    });

    test('the dark palette is the measured dark artboards', () {
      expect(skeletonTokensDark.shimmerBase, const Color(0xFF191A21));
      expect(skeletonTokensDark.shimmerHighlight, const Color(0xFF23242C));
      expect(skeletonTokensDark.bar, const Color(0xFF22232B));
    });

    test('forBrightness picks the matching palette', () {
      expect(skeletonTokensFor(Brightness.light), same(skeletonTokensLight));
      expect(skeletonTokensFor(Brightness.dark), same(skeletonTokensDark));
    });

    test('both real themes carry the tokens', () {
      expect(
        AppTheme.light.extension<SkeletonTokens>(),
        same(skeletonTokensLight),
      );
      expect(
        AppTheme.dark.extension<SkeletonTokens>(),
        same(skeletonTokensDark),
      );
    });

    test('copyWith and lerp keep the measured values whole', () {
      expect(skeletonTokensLight.copyWith(), same(skeletonTokensLight));
      expect(
        skeletonTokensLight.lerp(skeletonTokensDark, 0.2),
        same(skeletonTokensLight),
      );
      expect(
        skeletonTokensLight.lerp(skeletonTokensDark, 0.8),
        same(skeletonTokensDark),
      );
      expect(skeletonTokensLight.lerp(null, 0.8), same(skeletonTokensLight));
    });

    testWidgets('of reads the tokens from the theme in scope', (tester) async {
      late SkeletonTokens seen;
      await tester.pumpApp(
        Builder(
          builder: (context) {
            seen = SkeletonTokens.of(context);
            return const SizedBox();
          },
        ),
        brightness: Brightness.dark,
      );
      expect(seen, same(skeletonTokensDark));
    });
  });
}
