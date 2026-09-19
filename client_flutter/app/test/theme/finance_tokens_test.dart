import 'package:finance_a2ui_client/src/theme/finance_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a = FinanceTokens(
    gain: Color(0xFF000000),
    loss: Color(0xFF111111),
    neutral: Color(0xFF222222),
    brandAccent: Color(0xFF333333),
  );
  const b = FinanceTokens(
    gain: Color(0xFFFFFFFF),
    loss: Color(0xFFEEEEEE),
    neutral: Color(0xFFDDDDDD),
    brandAccent: Color(0xFFCCCCCC),
  );

  group('copyWith', () {
    test('changes one field and preserves the rest', () {
      final FinanceTokens result = a.copyWith(gain: const Color(0xFF00FF00));

      expect(result.gain, const Color(0xFF00FF00));
      expect(result.loss, a.loss);
      expect(result.neutral, a.neutral);
      expect(result.brandAccent, a.brandAccent);
    });

    test('with no arguments preserves every field', () {
      final FinanceTokens result = a.copyWith();

      expect(result.gain, a.gain);
      expect(result.loss, a.loss);
      expect(result.neutral, a.neutral);
      expect(result.brandAccent, a.brandAccent);
    });
  });

  group('lerp', () {
    test('at t=0 returns the receiver values', () {
      final FinanceTokens result = a.lerp(b, 0);

      expect(result.gain, a.gain);
      expect(result.loss, a.loss);
      expect(result.neutral, a.neutral);
      expect(result.brandAccent, a.brandAccent);
    });

    test('at t=1 returns the other values', () {
      final FinanceTokens result = a.lerp(b, 1);

      expect(result.gain, b.gain);
      expect(result.loss, b.loss);
      expect(result.neutral, b.neutral);
      expect(result.brandAccent, b.brandAccent);
    });

    test('with a non-FinanceTokens other returns this', () {
      expect(identical(a.lerp(null, 0.5), a), isTrue);
    });
  });
}
