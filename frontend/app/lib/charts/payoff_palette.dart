import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The colours a payoff curve needs that `ChartPalette` has no role for.
///
/// A **second** `ThemeExtension` rather than three more fields on
/// `ChartPalette`, for two reasons recorded in `specs/frontend/0005` OD-6.
/// `ChartPalette` is already 141 lines and each field costs it about eight
/// (constructor, doc, `_values`, `copyWith` twice, `lerp`), so three more
/// would push it through the 150-line gate; and three sibling components are
/// editing that file this week, so widening it is also the change most likely
/// to conflict.
///
/// It restates no colour. The curve is `ChartPalette.barTotal` and the marker
/// halo is `surface`, both already exact, so a painter reads both extensions
/// rather than a copy of either. The two region tints look like exceptions
/// and are not: they are `ChartPalette`'s own `barGain`/`barLoss` **derived**
/// at the artboard's wash alpha in `ChartTokens`, so recolouring a bar moves
/// its wash with it.
@immutable
class PayoffPalette extends ThemeExtension<PayoffPalette> {
  /// Creates a palette. Every colour is required, for the same reason
  /// `ChartPalette` requires its own: a chart drawn in a fallback colour
  /// looks plausible and is wrong.
  const PayoffPalette({
    required this.breakEven,
    required this.zeroBaseline,
    required this.axisLabel,
    required this.lossRegion,
    required this.gainRegion,
  });

  /// Reads the palette from [context]. Throws when the theme carries none.
  static PayoffPalette of(BuildContext context) =>
      Theme.of(context).extension<PayoffPalette>()!;

  /// The amber of the break-even rule and its label.
  ///
  /// Carried although nothing draws it yet: the payload cannot say where
  /// break-even is (spec `frontend/0005` OD-1), so the rule is deferred until
  /// the backend sends a machine-readable marker. The token is measured and
  /// kept so that change is a painter edit and not a second trip to design.
  final Color breakEven;

  /// The `y = 0` rule — heavier than a gridline and lighter than the curve.
  final Color zeroBaseline;

  /// Tick labels under the plot. Lighter than `ChartPalette.mutedLabel`,
  /// which the design reserves for figures rather than axis furniture.
  final Color axisLabel;

  /// The wash over everything below zero.
  ///
  /// Pre-composited rather than `barLoss` with an alpha applied at the point
  /// of use, because the alpha is **not the same in the two themes** — .07 in
  /// light, .10 in dark, both measured — and a widget that reached for the
  /// right one would be branching on brightness, which is the thing a
  /// `ThemeExtension` exists to avoid.
  final Color lossRegion;

  /// The wash over everything above zero. See [lossRegion].
  final Color gainRegion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PayoffPalette && listEquals(_values, other._values);

  @override
  int get hashCode => Object.hashAll(_values);

  List<Object?> get _values => <Object?>[
    breakEven,
    zeroBaseline,
    axisLabel,
    lossRegion,
    gainRegion,
  ];

  @override
  PayoffPalette copyWith({
    Color? breakEven,
    Color? zeroBaseline,
    Color? axisLabel,
    Color? lossRegion,
    Color? gainRegion,
  }) => PayoffPalette(
    breakEven: breakEven ?? this.breakEven,
    zeroBaseline: zeroBaseline ?? this.zeroBaseline,
    axisLabel: axisLabel ?? this.axisLabel,
    lossRegion: lossRegion ?? this.lossRegion,
    gainRegion: gainRegion ?? this.gainRegion,
  );

  @override
  PayoffPalette lerp(covariant PayoffPalette? other, double t) {
    if (other == null) return this;
    return PayoffPalette(
      breakEven: _lerp(breakEven, other.breakEven, t),
      zeroBaseline: _lerp(zeroBaseline, other.zeroBaseline, t),
      axisLabel: _lerp(axisLabel, other.axisLabel, t),
      lossRegion: _lerp(lossRegion, other.lossRegion, t),
      gainRegion: _lerp(gainRegion, other.gainRegion, t),
    );
  }

  static Color _lerp(Color a, Color b, double t) => Color.lerp(a, b, t) ?? b;
}
