import 'package:flutter/material.dart';

/// The sign-in screen's palette, measured off `Login.dc.html` with
/// `getComputedStyle`, light and dark (spec frontend/0008 §2).
///
/// "Semantic finance colors reserved for data screens; this screen stays
/// calm and neutral" — so nothing here is a gain or a loss hue, and the one
/// accent is the brand indigo.
class LoginTokens extends ThemeExtension<LoginTokens> {
  /// Creates the palette.
  const LoginTokens({
    required this.page,
    required this.title,
    required this.subtitle,
    required this.googleBorder,
    required this.googleFill,
    required this.googleText,
    required this.divider,
    required this.dividerText,
    required this.fieldBorder,
    required this.fieldFocus,
    required this.fieldLabel,
    required this.placeholder,
    required this.helper,
    required this.primary,
    required this.primaryText,
    required this.invite,
    required this.inviteLink,
    required this.footer,
    required this.footerLink,
    required this.footerSeparator,
    required this.snack,
    required this.snackText,
    required this.snackIcon,
    required this.snackAction,
  });

  /// The tokens of the theme in scope.
  static LoginTokens of(BuildContext context) =>
      Theme.of(context).extension<LoginTokens>()!;

  /// Page background.
  final Color page;

  /// `Portfolio companion`.
  final Color title;

  /// The one-line pitch under it.
  final Color subtitle;

  /// Google button: border.
  final Color googleBorder;

  /// Google button: fill.
  final Color googleFill;

  /// Google button: words.
  final Color googleText;

  /// The `or` rule.
  final Color divider;

  /// The `or` itself.
  final Color dividerText;

  /// E-mail field: resting border.
  final Color fieldBorder;

  /// E-mail field: focused border and label.
  final Color fieldFocus;

  /// E-mail field: resting label.
  final Color fieldLabel;

  /// E-mail field: placeholder.
  final Color placeholder;

  /// The validation helper under the field.
  final Color helper;

  /// `Continue with email`: fill.
  final Color primary;

  /// `Continue with email`: words.
  final Color primaryText;

  /// `Access is invite-only…`.
  final Color invite;

  /// `Request access`.
  final Color inviteLink;

  /// The footer's words.
  final Color footer;

  /// The footer's links.
  final Color footerLink;

  /// The footer's `·`.
  final Color footerSeparator;

  /// The error snackbar: fill.
  final Color snack;

  /// The error snackbar: words.
  final Color snackText;

  /// The error snackbar: the `!` ring.
  final Color snackIcon;

  /// The error snackbar: `Dismiss`.
  final Color snackAction;

  /// The logo's gradient, the same on both artboards.
  static const List<Color> logoGradient = <Color>[
    Color(0xFF4F5DFF),
    Color(0xFF7A5CFF),
  ];

  /// The glow the hero casts under the logo tile, also artboard-independent.
  static const Color logoGlow = Color(0x8C4F5DFF);

  /// Google's own four brand colours, in the order `GoogleMarkPainter` paints
  /// them: **blue, red, yellow, green**.
  ///
  /// They are Google's rather than this design's, so they do not follow the
  /// artboard and are a `static const` beside [logoGradient]. They are here at
  /// all — rather than beside the painter that uses them — because a colour
  /// literal lives in a `*_tokens.dart` and nowhere else, which
  /// `app/test/architecture/color_rules_test.dart` now asserts instead of
  /// `frontend/CLAUDE.md` claiming it (spec frontend/0029 OD-4).
  static const List<Color> googleMark = <Color>[
    Color(0xFF4285F4),
    Color(0xFFEA4335),
    Color(0xFFFBBC05),
    Color(0xFF34A853),
  ];

  @override
  LoginTokens copyWith() => this;

  @override
  LoginTokens lerp(ThemeExtension<LoginTokens>? other, double t) =>
      t < 0.5 ? this : (other as LoginTokens? ?? this);
}
