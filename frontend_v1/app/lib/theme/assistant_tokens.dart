import 'package:flutter/material.dart';

/// The Assistant tab's palette, measured off `FlowA-Assistant.dc.html`
/// (spec frontend/0011 §2) — what `HomeTokens` does not already carry.
class AssistantTokens extends ThemeExtension<AssistantTokens> {
  /// Creates the palette.
  const AssistantTokens({
    required this.avatar,
    required this.pill,
    required this.pillText,
    required this.badge,
    required this.badgeDot,
    required this.badgeText,
    required this.bubble,
    required this.bubbleText,
    required this.label,
    required this.dot,
    required this.skeletonBar,
    required this.composing,
    required this.chip,
    required this.chipBorder,
    required this.chipText,
    required this.fieldBorder,
    required this.placeholder,
    required this.mic,
    required this.micGlyph,
    required this.send,
    required this.sendGlyph,
    required this.sendDisabled,
  });

  /// The tokens of the theme in scope.
  static AssistantTokens of(BuildContext context) =>
      Theme.of(context).extension<AssistantTokens>()!;

  /// The 135° gradient of the assistant's avatar, header and label alike.
  final List<Color> avatar;

  /// `Gemini · A2UI`: fill.
  final Color pill;

  /// `Gemini · A2UI`: words.
  final Color pillText;

  /// `Simulated`: fill.
  final Color badge;

  /// `Simulated`: its dot.
  final Color badgeDot;

  /// `Simulated`: words.
  final Color badgeText;

  /// The user's bubble.
  final Color bubble;

  /// The user's words.
  final Color bubbleText;

  /// `Assistant`, under the answer's avatar.
  final Color label;

  /// The three streaming dots, and `Composing UI…`'s dot.
  final Color dot;

  /// The skeleton's bars and pills.
  final Color skeletonBar;

  /// `Composing UI…`.
  final Color composing;

  /// A follow-up chip: fill.
  final Color chip;

  /// A follow-up chip: border.
  final Color chipBorder;

  /// A follow-up chip: words.
  final Color chipText;

  /// The composer field's border.
  final Color fieldBorder;

  /// `Ask about your portfolio…`.
  final Color placeholder;

  /// The mic button: fill.
  final Color mic;

  /// The mic button: glyph.
  final Color micGlyph;

  /// The send button: fill.
  final Color send;

  /// The send button: glyph.
  final Color sendGlyph;

  /// The send button while a turn runs.
  final Color sendDisabled;

  @override
  AssistantTokens copyWith() => this;

  @override
  AssistantTokens lerp(ThemeExtension<AssistantTokens>? other, double t) =>
      t < 0.5 ? this : (other as AssistantTokens? ?? this);
}
