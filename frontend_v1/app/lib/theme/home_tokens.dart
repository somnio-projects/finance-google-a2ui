import 'package:flutter/material.dart';

/// The Home shell's colours, **measured** from `Home.dc.html` (spec 0026 §2).
///
/// Every value was read out of the rendered page with `getComputedStyle`,
/// light and dark, the way `chart_tokens.dart` and `app_color_tokens.dart`
/// were.
/// They are a `ThemeExtension` rather than more `ColorScheme` slots because
/// Material has no role for "the pill behind a selected tab" or "the dot in
/// the simulation badge", and inventing one would put a guess where a
/// measurement belongs.
@immutable
class HomeTokens extends ThemeExtension<HomeTokens> {
  /// Creates the token set.
  const HomeTokens({
    required this.page,
    required this.header,
    required this.card,
    required this.cardBorder,
    required this.text,
    required this.muted,
    required this.gain,
    required this.loss,
    required this.badge,
    required this.badgeDot,
    required this.badgeText,
    required this.segmentBorder,
    required this.segmentSelected,
    required this.segmentSelectedText,
    required this.segmentText,
    required this.chip,
    required this.chipBorder,
    required this.chipText,
    required this.ticker,
    required this.tickerText,
    required this.nav,
    required this.navBorder,
    required this.navPill,
    required this.navSelectedText,
    required this.navText,
    required this.catalogBorder,
    required this.catalogText,
    required this.rowDivider,
    required this.accent,
  });

  /// The tokens the current theme carries.
  static HomeTokens of(BuildContext context) =>
      Theme.of(context).extension<HomeTokens>()!;

  /// The page behind every surface.
  final Color page;

  /// The header strip.
  final Color header;

  /// A card.
  final Color card;

  /// A card's hairline.
  final Color cardBorder;

  /// Body text.
  final Color text;

  /// Quiet text.
  final Color muted;

  /// A gain, and the sparkline.
  final Color gain;

  /// A loss.
  final Color loss;

  /// Simulation badge: badge.
  final Color badge;

  /// Simulation badge: badgeDot.
  final Color badgeDot;

  /// Simulation badge: badgeText.
  final Color badgeText;

  /// Range selector: segmentBorder.
  final Color segmentBorder;

  /// Range selector: segmentSelected.
  final Color segmentSelected;

  /// Range selector: segmentSelectedText.
  final Color segmentSelectedText;

  /// Range selector: segmentText.
  final Color segmentText;

  /// Question chip: chip.
  final Color chip;

  /// Question chip: chipBorder.
  final Color chipBorder;

  /// Question chip: chipText.
  final Color chipText;

  /// Movers ticker tile: ticker.
  final Color ticker;

  /// Movers ticker tile: tickerText.
  final Color tickerText;

  /// Tab bar: nav.
  final Color nav;

  /// Tab bar: navBorder.
  final Color navBorder;

  /// Tab bar: navPill.
  final Color navPill;

  /// Tab bar: navSelectedText.
  final Color navSelectedText;

  /// Tab bar: navText.
  final Color navText;

  /// `Catalog` chip: catalogBorder.
  final Color catalogBorder;

  /// `Catalog` chip: catalogText.
  final Color catalogText;

  /// A hairline between list rows.
  final Color rowDivider;

  /// The indigo the design uses for the avatar and the section dot.
  final Color accent;

  @override
  HomeTokens copyWith() => this;

  @override
  HomeTokens lerp(ThemeExtension<HomeTokens>? other, double t) =>
      t < 0.5 ? this : (other as HomeTokens? ?? this);
}
