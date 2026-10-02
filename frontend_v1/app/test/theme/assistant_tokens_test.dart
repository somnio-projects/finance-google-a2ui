import 'package:finance_app/theme/app_theme.dart';
import 'package:finance_app/theme/assistant_palettes.dart';
import 'package:finance_app/theme/assistant_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(AssistantTokens, () {
    test('both palettes are the measured artboards', () {
      expect(assistantTokensLight.bubble, const Color(0xFF4F5DFF));
      expect(assistantTokensLight.pill, const Color(0xFFEAE7F5));
      expect(assistantTokensLight.badgeText, const Color(0xFF4A3F8A));
      expect(assistantTokensLight.chipText, const Color(0xFF3A2F70));
      expect(assistantTokensLight.composing, const Color(0xFF8A5CF0));
      expect(assistantTokensDark.pill, const Color(0xFF232036));
      expect(assistantTokensDark.badgeDot, const Color(0xFFB9C0FF));
      expect(assistantTokensDark.send, const Color(0xFFB9C0FF));
      expect(assistantTokensDark.sendGlyph, const Color(0xFF151A54));
      expect(assistantTokensFor(Brightness.dark), same(assistantTokensDark));
      expect(assistantTokensFor(Brightness.light), same(assistantTokensLight));
      expect(
        AppTheme.light.extension<AssistantTokens>(),
        same(assistantTokensLight),
      );
      expect(
        AppTheme.dark.extension<AssistantTokens>(),
        same(assistantTokensDark),
      );
      expect(assistantTokensLight.copyWith(), same(assistantTokensLight));
      expect(
        assistantTokensLight.lerp(assistantTokensDark, 0.2),
        same(assistantTokensLight),
      );
      expect(
        assistantTokensLight.lerp(assistantTokensDark, 0.8),
        same(assistantTokensDark),
      );
      expect(assistantTokensLight.lerp(null, 0.8), same(assistantTokensLight));
    });
  });
}
