import 'package:flutter/material.dart';

/// The spacing scale, carried on the theme rather than in constants.
///
/// A `ThemeExtension` is what lets a widget read spacing from its
/// `BuildContext` (`.claude/rules/flutter/ui-theming.md`): the scale can then
/// differ per theme — a denser desktop variant, a larger accessible one —
/// without a single widget changing.
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  /// Creates a spacing scale.
  const AppSpacing({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
  });

  /// The scale every theme in this app uses today.
  static const AppSpacing standard = AppSpacing(xs: 4, sm: 8, md: 16, lg: 24);

  /// Reads the scale from [context], falling back to [standard] when no
  /// theme supplied one (which is what a bare `MaterialApp` in a test does).
  static AppSpacing of(BuildContext context) =>
      Theme.of(context).extension<AppSpacing>() ?? standard;

  /// Hairline gaps between tightly related text.
  final double xs;

  /// Gaps inside a control.
  final double sm;

  /// The default padding of a card or a list row.
  final double md;

  /// Separation between sections of a page.
  final double lg;

  @override
  AppSpacing copyWith({double? xs, double? sm, double? md, double? lg}) =>
      AppSpacing(
        xs: xs ?? this.xs,
        sm: sm ?? this.sm,
        md: md ?? this.md,
        lg: lg ?? this.lg,
      );

  @override
  AppSpacing lerp(covariant AppSpacing? other, double t) {
    if (other == null) return this;
    return AppSpacing(
      xs: lerpDouble(xs, other.xs, t),
      sm: lerpDouble(sm, other.sm, t),
      md: lerpDouble(md, other.md, t),
      lg: lerpDouble(lg, other.lg, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSpacing &&
          other.xs == xs &&
          other.sm == sm &&
          other.md == md &&
          other.lg == lg;

  @override
  int get hashCode => Object.hash(xs, sm, md, lg);

  /// Linearly interpolates two spacing values.
  ///
  /// `dart:ui`'s `lerpDouble` returns a nullable double for nullable inputs;
  /// these are never null, so this keeps the call sites free of `!`.
  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
