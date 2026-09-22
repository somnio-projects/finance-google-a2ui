import 'package:flutter/material.dart';

/// The Activity tab's palette, measured off `Activity.dc.html`
/// (spec frontend/0009 §2): one icon tile per kind, two term badges.
class ActivityTokens extends ThemeExtension<ActivityTokens> {
  /// Creates the palette.
  const ActivityTokens({
    required this.buyTile,
    required this.buyGlyph,
    required this.sellTile,
    required this.sellGlyph,
    required this.dividendTile,
    required this.dividendGlyph,
    required this.depositTile,
    required this.depositGlyph,
    required this.shortBadge,
    required this.shortBadgeText,
    required this.longBadge,
    required this.longBadgeText,
    required this.noteDot,
    required this.note,
    required this.section,
    required this.badge,
  });

  /// The tokens of the theme in scope.
  static ActivityTokens of(BuildContext context) =>
      Theme.of(context).extension<ActivityTokens>()!;

  /// `↓` tile.
  final Color buyTile;

  /// `↓`.
  final Color buyGlyph;

  /// `↑` tile.
  final Color sellTile;

  /// `↑`.
  final Color sellGlyph;

  /// `$` tile.
  final Color dividendTile;

  /// `$`.
  final Color dividendGlyph;

  /// `+` tile.
  final Color depositTile;

  /// `+`.
  final Color depositGlyph;

  /// `ST gain`: fill.
  final Color shortBadge;

  /// `ST gain`: words.
  final Color shortBadgeText;

  /// `LT gain`: fill.
  final Color longBadge;

  /// `LT gain`: words.
  final Color longBadgeText;

  /// The simulation note's amber dot.
  final Color noteDot;

  /// The simulation note's words.
  final Color note;

  /// `TODAY` · `THIS WEEK` · the months.
  final Color section;

  /// `Buy` · `Dividend` · `Deposit` under an amount.
  final Color badge;

  /// The tile and glyph for [kind].
  (Color, Color) tileFor(String kind) => switch (kind) {
    'sell' => (sellTile, sellGlyph),
    'dividend' => (dividendTile, dividendGlyph),
    'deposit' => (depositTile, depositGlyph),
    _ => (buyTile, buyGlyph),
  };

  @override
  ActivityTokens copyWith() => this;

  @override
  ActivityTokens lerp(ThemeExtension<ActivityTokens>? other, double t) =>
      t < 0.5 ? this : (other as ActivityTokens? ?? this);
}

/// `Activity.dc.html`, light.
const ActivityTokens activityTokensLight = ActivityTokens(
  buyTile: Color(0xFFEAE7F5),
  buyGlyph: Color(0xFF4A3F8A),
  sellTile: Color(0xFFF0EEF4),
  sellGlyph: Color(0xFF5F6169),
  dividendTile: Color(0xFFDBEEE7),
  dividendGlyph: Color(0xFF0C6A52),
  depositTile: Color(0xFFE2ECF7),
  depositGlyph: Color(0xFF2B5A86),
  shortBadge: Color(0xFFFBE9C8),
  shortBadgeText: Color(0xFF8A5A00),
  longBadge: Color(0xFFCFE9E3),
  longBadgeText: Color(0xFF0C5A52),
  noteDot: Color(0xFFF0A52E),
  note: Color(0xFF7C7E88),
  section: Color(0xFF5F6169),
  badge: Color(0xFF8A8D96),
);

/// `Activity.dc.html`, dark.
const ActivityTokens activityTokensDark = ActivityTokens(
  buyTile: Color(0xFF232036),
  buyGlyph: Color(0xFFC9CBFF),
  sellTile: Color(0xFF1F2028),
  sellGlyph: Color(0xFFA4A6B0),
  dividendTile: Color(0xFF153029),
  dividendGlyph: Color(0xFF4ADE9E),
  depositTile: Color(0xFF182634),
  depositGlyph: Color(0xFF83B3E0),
  shortBadge: Color(0xFF3A2C12),
  shortBadgeText: Color(0xFFFFC971),
  longBadge: Color(0xFF12332C),
  longBadgeText: Color(0xFF4ADE9E),
  noteDot: Color(0xFFFFBF5C),
  note: Color(0xFF8F929C),
  section: Color(0xFFA4A6B0),
  badge: Color(0xFF8F929C),
);

/// The palette for [brightness].
ActivityTokens activityTokensFor(Brightness brightness) =>
    brightness == Brightness.dark ? activityTokensDark : activityTokensLight;
