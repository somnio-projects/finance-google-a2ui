import 'package:finance_app/theme/app_theme.dart';
import 'package:finance_app/theme/login_palettes.dart';
import 'package:finance_app/theme/login_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  group(LoginTokens, () {
    test('both palettes are the measured artboards', () {
      expect(loginTokensLight.page, const Color(0xFFFDFBFF));
      expect(loginTokensLight.primary, const Color(0xFF4F5DFF));
      expect(loginTokensLight.snack, const Color(0xFF322F35));
      expect(loginTokensDark.page, const Color(0xFF0E0F13));
      expect(loginTokensDark.primary, const Color(0xFFB9C0FF));
      expect(loginTokensDark.primaryText, const Color(0xFF151A54));
      expect(LoginTokens.logoGradient.first, const Color(0xFF4F5DFF));
    });

    test('both themes carry the tokens, and lerp snaps', () {
      expect(AppTheme.light.extension<LoginTokens>(), same(loginTokensLight));
      expect(AppTheme.dark.extension<LoginTokens>(), same(loginTokensDark));
      expect(loginTokensFor(Brightness.dark), same(loginTokensDark));
      expect(loginTokensLight.copyWith(), same(loginTokensLight));
      expect(
        loginTokensLight.lerp(loginTokensDark, 0.2),
        same(loginTokensLight),
      );
      expect(
        loginTokensLight.lerp(loginTokensDark, 0.8),
        same(loginTokensDark),
      );
      expect(loginTokensLight.lerp(null, 0.8), same(loginTokensLight));
    });

    testWidgets('of reads the theme in scope', (tester) async {
      late LoginTokens seen;
      await tester.pumpApp(
        Builder(
          builder: (context) {
            seen = LoginTokens.of(context);
            return const SizedBox();
          },
        ),
        brightness: Brightness.dark,
      );
      expect(seen, same(loginTokensDark));
    });
  });
}
