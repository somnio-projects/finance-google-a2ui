import 'package:finance_app/theme/catalog_zone_colors.dart';
import 'package:flutter/material.dart';

/// The developer catalog's colours, **measured** from `Catalog_Index.dc.html`
/// and the six detail pages (spec frontend/0013 §2), light and dark.
///
/// Every value was read out of the pages' inline styles. They are a
/// `ThemeExtension` because Material has no role for "the thumbnail well
/// behind a live component" or "the mono badge on a gallery card", and the
/// four semantic swatches of the token legend — gain, loss, short-term,
/// long-term — are the colours every other page uses, pinned here so the
/// legend cannot describe a palette the components do not draw.
@immutable
class CatalogTokens extends ThemeExtension<CatalogTokens> {
  /// Creates the token set.
  const CatalogTokens({
    required this.board,
    required this.topBar,
    required this.topBarBorder,
    required this.text,
    required this.body,
    required this.muted,
    required this.quiet,
    required this.accent,
    required this.accentDot,
    required this.tokenSwatch,
    required this.pill,
    required this.pillText,
    required this.componentPill,
    required this.componentPillText,
    required this.card,
    required this.cardBorder,
    required this.thumbnail,
    required this.thumbnailBorder,
    required this.badge,
    required this.badgeText,
    required this.rule,
    required this.gain,
    required this.loss,
    required this.shortTerm,
    required this.longTerm,
    required this.shimmer,
    required this.skeletonBar,
    required this.zones,
  });

  /// The tokens the current theme carries.
  static CatalogTokens of(BuildContext context) =>
      Theme.of(context).extension<CatalogTokens>()!;

  /// The 1024 board behind everything.
  final Color board;

  /// The doc top bar.
  final Color topBar;

  /// The top bar's bottom hairline.
  final Color topBarBorder;

  /// Headline text.
  final Color text;

  /// Body text.
  final Color body;

  /// Quieter text: card descriptions, the mono badge.
  final Color muted;

  /// Quietest text: breadcrumb, state labels, `Simulated data`.
  final Color quiet;

  /// The eyebrow, the zone labels, `View schema →`, the current crumb.
  final Color accent;

  /// The 6px `Simulated data` dot.
  final Color accentDot;

  /// The `Design tokens` swatch.
  final Color tokenSwatch;

  /// Header pill fill.
  final Color pill;

  /// Header pill text.
  final Color pillText;

  /// The teal component pill on a detail page: fill.
  final Color componentPill;

  /// The teal component pill on a detail page: text.
  final Color componentPillText;

  /// A card, and every zone-1 state card.
  final Color card;

  /// A card's hairline.
  final Color cardBorder;

  /// The well behind a card's live thumbnail.
  final Color thumbnail;

  /// The hairline under that well.
  final Color thumbnailBorder;

  /// The mono badge on a card: fill.
  final Color badge;

  /// The mono badge on a card: text.
  final Color badgeText;

  /// The hairline beside a zone label.
  final Color rule;

  /// Legend: a gain.
  final Color gain;

  /// Legend: a loss.
  final Color loss;

  /// Legend: a short-term lot.
  final Color shortTerm;

  /// Legend: a long-term lot.
  final Color longTerm;

  /// The shimmer of a loading skeleton.
  final Color shimmer;

  /// A flat skeleton bar.
  final Color skeletonBar;

  /// The three zones' colours.
  final CatalogZoneColors zones;

  @override
  CatalogTokens copyWith() => this;

  @override
  CatalogTokens lerp(ThemeExtension<CatalogTokens>? other, double t) =>
      t < 0.5 ? this : (other as CatalogTokens? ?? this);
}
