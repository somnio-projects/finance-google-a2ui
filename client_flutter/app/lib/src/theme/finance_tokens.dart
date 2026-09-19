import 'package:flutter/material.dart';

/// Semantic colour tokens for the finance domain.
///
/// These are the only place raw colour literals are allowed. Feature widgets
/// read them through [FinanceTokens.of] so that changing a value here
/// re-themes the app without touching anything under `features/`.
@immutable
class FinanceTokens extends ThemeExtension<FinanceTokens> {
  const FinanceTokens({
    required this.gain,
    required this.loss,
    required this.neutral,
    required this.brandAccent,
  });

  /// Upward price movement.
  final Color gain;

  /// Downward price movement.
  final Color loss;

  /// Flat / unchanged price movement.
  final Color neutral;

  /// Brand accent, used as the Material 3 seed colour.
  final Color brandAccent;

  static const FinanceTokens light = FinanceTokens(
    gain: Color(0xFF1B873B),
    loss: Color(0xFFC3372B),
    neutral: Color(0xFF6B7280),
    brandAccent: Color(0xFFF7931A),
  );

  static const FinanceTokens dark = FinanceTokens(
    gain: Color(0xFF4ADE80),
    loss: Color(0xFFF87171),
    neutral: Color(0xFF9CA3AF),
    brandAccent: Color(0xFFF7931A),
  );

  /// The tokens registered on the ambient theme.
  ///
  /// Falls back to [light] so that a widget pumped without the app theme
  /// still renders rather than throwing.
  static FinanceTokens of(BuildContext context) =>
      Theme.of(context).extension<FinanceTokens>() ?? light;

  @override
  FinanceTokens copyWith({
    Color? gain,
    Color? loss,
    Color? neutral,
    Color? brandAccent,
  }) {
    return FinanceTokens(
      gain: gain ?? this.gain,
      loss: loss ?? this.loss,
      neutral: neutral ?? this.neutral,
      brandAccent: brandAccent ?? this.brandAccent,
    );
  }

  @override
  FinanceTokens lerp(ThemeExtension<FinanceTokens>? other, double t) {
    if (other is! FinanceTokens) return this;
    return FinanceTokens(
      gain: Color.lerp(gain, other.gain, t)!,
      loss: Color.lerp(loss, other.loss, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      brandAccent: Color.lerp(brandAccent, other.brandAccent, t)!,
    );
  }
}
