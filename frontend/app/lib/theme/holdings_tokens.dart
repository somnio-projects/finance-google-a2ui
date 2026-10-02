import 'package:flutter/material.dart';

/// The Holdings tab's palette, measured off `Holdings.dc.html`
/// (spec frontend/0009 §2) — what `HomeTokens` does not already carry.
class HoldingsTokens extends ThemeExtension<HoldingsTokens> {
  /// Creates the palette.
  const HoldingsTokens({
    required this.toggle,
    required this.toggleSelected,
    required this.toggleSelectedText,
    required this.toggleText,
    required this.tileBorder,
    required this.expandedBorder,
    required this.expandedHead,
    required this.statTile,
    required this.askFill,
    required this.askBorder,
    required this.askText,
    required this.askChevron,
    required this.cashBadge,
    required this.cashBadgeText,
    required this.neutralAccent,
  });

  /// The tokens of the theme in scope.
  static HoldingsTokens of(BuildContext context) =>
      Theme.of(context).extension<HoldingsTokens>()!;

  /// The selected toggle pill's drop shadow, the same on both artboards.
  ///
  /// A `static const`, like `LoginTokens.logoGradient`: the artboards draw one
  /// value, so a brightness-keyed field would be the same colour twice. It is
  /// here rather than in `holdings_toggle.dart` because a colour literal lives
  /// in a `*_tokens.dart` and nowhere else — asserted by
  /// `app/test/architecture/color_rules_test.dart` (spec frontend/0029 OD-4).
  static const Color toggleShadow = Color(0x14000000);

  /// The indigo glow under an expanded position tile.
  static const Color expandedGlow = Color(0x2E4F5DFF);

  /// The `Ask about this position` icon's gradient, top-left to bottom-right.
  static const List<Color> askIconGradient = <Color>[
    Color(0xFF4F5DFF),
    Color(0xFF7A5CFF),
  ];

  /// `By asset class | By sector`: track.
  final Color toggle;

  /// `By asset class | By sector`: the selected pill.
  final Color toggleSelected;

  /// Its words.
  final Color toggleSelectedText;

  /// The other pill's words.
  final Color toggleText;

  /// A collapsed position tile's border.
  final Color tileBorder;

  /// The expanded tile's border.
  final Color expandedBorder;

  /// The expanded tile's head.
  final Color expandedHead;

  /// `Day` · `Price` · `Weight` tiles.
  final Color statTile;

  /// `Ask the assistant about this`: fill (the gradient's start).
  final List<Color> askFill;

  /// Its border.
  final Color askBorder;

  /// Its words.
  final Color askText;

  /// Its `›`.
  final Color askChevron;

  /// The `USD` badge.
  final Color cashBadge;

  /// Its letters.
  final Color cashBadgeText;

  /// The left accent of a row that did not move.
  final Color neutralAccent;

  @override
  HoldingsTokens copyWith() => this;

  @override
  HoldingsTokens lerp(ThemeExtension<HoldingsTokens>? other, double t) =>
      t < 0.5 ? this : (other as HoldingsTokens? ?? this);
}

/// `Holdings.dc.html`, light.
const HoldingsTokens holdingsTokensLight = HoldingsTokens(
  toggle: Color(0xFFEFEAF7),
  toggleSelected: Color(0xFFFFFFFF),
  toggleSelectedText: Color(0xFF3A2F70),
  toggleText: Color(0xFF6F6A86),
  tileBorder: Color(0xFFEAE7F0),
  expandedBorder: Color(0xFFD7D2E6),
  expandedHead: Color(0xFFF4F2FC),
  statTile: Color(0xFFF7F6FB),
  askFill: <Color>[Color(0xFFEEF0FF), Color(0xFFF3EDFF)],
  askBorder: Color(0xFFD9DCFF),
  askText: Color(0xFF3A2F70),
  askChevron: Color(0xFF7A5CFF),
  cashBadge: Color(0xFFEEF0F2),
  cashBadgeText: Color(0xFF5F6169),
  neutralAccent: Color(0xFF9AA0AA),
);

/// `Holdings.dc.html`, dark.
const HoldingsTokens holdingsTokensDark = HoldingsTokens(
  toggle: Color(0xFF232036),
  toggleSelected: Color(0xFF3A3556),
  toggleSelectedText: Color(0xFFE0E0FF),
  toggleText: Color(0xFF9A9AB0),
  tileBorder: Color(0xFF24252D),
  expandedBorder: Color(0xFF3A3556),
  expandedHead: Color(0xFF1B1C28),
  statTile: Color(0xFF101017),
  askFill: <Color>[Color(0xFF232036), Color(0xFF26283A)],
  askBorder: Color(0xFF3A3556),
  askText: Color(0xFFC9CBFF),
  askChevron: Color(0xFFB9C0FF),
  cashBadge: Color(0xFF1F2126),
  cashBadgeText: Color(0xFFA4A6B0),
  neutralAccent: Color(0xFF6F7280),
);

/// The palette for [brightness].
HoldingsTokens holdingsTokensFor(Brightness brightness) =>
    brightness == Brightness.dark ? holdingsTokensDark : holdingsTokensLight;
