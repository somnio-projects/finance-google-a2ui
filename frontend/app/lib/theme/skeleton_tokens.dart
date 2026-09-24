import 'package:flutter/material.dart';

/// The colours every loading skeleton is drawn in, measured off the catalog
/// pages' `Loading · skeleton` cards and the Home artboard's first-run hero
/// (spec frontend/0015 §2).
///
/// One palette for every skeleton, on purpose: a card that is still loading
/// has no component identity yet, so the shimmer is the same grey on the
/// Assistant, on Home and in the gallery — what changes is the *shape*.
class SkeletonTokens extends ThemeExtension<SkeletonTokens> {
  /// Creates the palette.
  const SkeletonTokens({
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.bar,
    required this.pill,
    required this.caption,
  });

  /// The tokens of the theme in scope.
  static SkeletonTokens of(BuildContext context) =>
      Theme.of(context).extension<SkeletonTokens>()!;

  /// The resting colour of a shimmering block (`.sk` at 25 % / 75 %).
  final Color shimmerBase;

  /// The band that sweeps across it (`.sk` at 50 %).
  final Color shimmerHighlight;

  /// A flat, pulsing bar — the payoff page's `.skel` rects and rules.
  final Color bar;

  /// The pill behind `payoff()…` on the payoff page's loading card.
  final Color pill;

  /// The spinner ring and the `get_holdings()…` / `Loading…` caption.
  final Color caption;

  @override
  SkeletonTokens copyWith() => this;

  @override
  SkeletonTokens lerp(ThemeExtension<SkeletonTokens>? other, double t) =>
      t < 0.5 || other is! SkeletonTokens ? this : other;
}

/// The tokens for [brightness].
SkeletonTokens skeletonTokensFor(Brightness brightness) =>
    brightness == Brightness.dark ? skeletonTokensDark : skeletonTokensLight;

/// Measured from the light artboards (`.sk`, `.skel`, `.shimL`).
const SkeletonTokens skeletonTokensLight = SkeletonTokens(
  shimmerBase: Color(0xFFECE8F2),
  shimmerHighlight: Color(0xFFF7F4FB),
  bar: Color(0xFFE6E2EF),
  pill: Color(0xFFEEF0F2),
  caption: Color(0xFF8A8D96),
);

/// Measured from the dark artboards (`.skd`, spec frontend/0016 §2).
const SkeletonTokens skeletonTokensDark = SkeletonTokens(
  shimmerBase: Color(0xFF191A21),
  shimmerHighlight: Color(0xFF23242C),
  bar: Color(0xFF22232B),
  pill: Color(0xFF1E2028),
  caption: Color(0xFF8A8D96),
);
