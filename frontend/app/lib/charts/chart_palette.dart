import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The colours a chart is drawn with, carried on the theme.
///
/// A `ThemeExtension` for the same reason `AppSpacing` is one
/// (`.claude/rules/flutter/ui-theming.md`): a widget reads its colours from
/// its `BuildContext`, so light and dark differ without a single widget
/// branching on brightness, and a test can pump either. The values live in
/// `ChartTokens` — one of the handful of `*_tokens.dart` files that may name
/// a `Color` at all (`frontend/CLAUDE.md` § *Drawing a chart*). It was the
/// only one when this was written; the tax-lot table, the shell and the
/// waterfall have since measured their own.
///
/// Material 3's `ColorScheme` cannot supply these. Gain, loss and "a total"
/// are **semantic** roles a finance chart needs and a generated scheme has no
/// slot for; deriving them from a seed would also throw away the design's
/// measured values, which is the opposite of what this ticket is for.
///
/// Equality compares one list rather than ten fields written out twice:
/// ten hand-written comparisons is ten chances to forget one, and `lerp` and
/// `copyWith` already enumerate the fields as often as is safe.
@immutable
class ChartPalette extends ThemeExtension<ChartPalette> {
  /// Creates a palette. Every colour is required — a chart with a missing
  /// role would fall back to something nobody chose.
  const ChartPalette({
    required this.surface,
    required this.border,
    required this.title,
    required this.barNeutral,
    required this.barGain,
    required this.barLoss,
    required this.barTotal,
    required this.connector,
    required this.rule,
    required this.mutedLabel,
  });

  /// Reads the palette from [context].
  ///
  /// Throws if the theme carries none, deliberately: a chart drawn in
  /// fallback colours looks plausible and is wrong, which is worse than a
  /// test that fails loudly.
  static ChartPalette of(BuildContext context) =>
      Theme.of(context).extension<ChartPalette>()!;

  /// The card a chart sits on.
  final Color surface;

  /// The hairline around that card.
  final Color border;

  /// The card's title text.
  final Color title;

  /// A bar that is neither a gain nor a loss — the opening total.
  final Color barNeutral;

  /// A contribution the backend marked `direction: up`.
  final Color barGain;

  /// A contribution the backend marked `direction: down`.
  final Color barLoss;

  /// The closing total, which the design gives its own accent.
  final Color barTotal;

  /// The hairline between two bars, from one's exit level to the next band.
  ///
  /// **Solid**, at 1 px: the UI Kit draws an unbroken run, and a dash in this
  /// app means a *reference* line, which is a different statement (spec
  /// frontend/0028 OD-2). It was dashed until then.
  final Color connector;

  /// The hairline under the plot, and the fill of a neutral chip.
  final Color rule;

  /// Axis labels, neutral value labels and chip text.
  final Color mutedLabel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartPalette && listEquals(_values, other._values);

  @override
  int get hashCode => Object.hashAll(_values);

  List<Object?> get _values => <Object?>[
    surface,
    border,
    title,
    barNeutral,
    barGain,
    barLoss,
    barTotal,
    connector,
    rule,
    mutedLabel,
  ];

  @override
  ChartPalette copyWith({
    Color? surface,
    Color? border,
    Color? title,
    Color? barNeutral,
    Color? barGain,
    Color? barLoss,
    Color? barTotal,
    Color? connector,
    Color? rule,
    Color? mutedLabel,
  }) => ChartPalette(
    surface: surface ?? this.surface,
    border: border ?? this.border,
    title: title ?? this.title,
    barNeutral: barNeutral ?? this.barNeutral,
    barGain: barGain ?? this.barGain,
    barLoss: barLoss ?? this.barLoss,
    barTotal: barTotal ?? this.barTotal,
    connector: connector ?? this.connector,
    rule: rule ?? this.rule,
    mutedLabel: mutedLabel ?? this.mutedLabel,
  );

  @override
  ChartPalette lerp(covariant ChartPalette? other, double t) {
    if (other == null) return this;
    return ChartPalette(
      surface: _lerp(surface, other.surface, t),
      border: _lerp(border, other.border, t),
      title: _lerp(title, other.title, t),
      barNeutral: _lerp(barNeutral, other.barNeutral, t),
      barGain: _lerp(barGain, other.barGain, t),
      barLoss: _lerp(barLoss, other.barLoss, t),
      barTotal: _lerp(barTotal, other.barTotal, t),
      connector: _lerp(connector, other.connector, t),
      rule: _lerp(rule, other.rule, t),
      mutedLabel: _lerp(mutedLabel, other.mutedLabel, t),
    );
  }

  /// `Color.lerp` is nullable for nullable inputs; these never are, so this
  /// keeps the call sites above free of `!` (the shape `AppSpacing` uses).
  static Color _lerp(Color a, Color b, double t) => Color.lerp(a, b, t) ?? b;
}
