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

  /// Brand accent. Flat across brightnesses — it only ever appears as an
  /// icon/illustration tint, never as a filled surface, so it doesn't need a
  /// separate high-contrast variant the way a theme's primary colour does.
  final Color brandAccent;

  static const FinanceTokens light = FinanceTokens(
    gain: Color(0xFF12805C),
    loss: Color(0xFFC0362C),
    neutral: Color(0xFF5F6169),
    brandAccent: Color(0xFF4F5DFF),
  );

  static const FinanceTokens dark = FinanceTokens(
    gain: Color(0xFF4ADE9E),
    loss: Color(0xFFFF6B5E),
    neutral: Color(0xFFA4A6B0),
    brandAccent: Color(0xFF4F5DFF),
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
