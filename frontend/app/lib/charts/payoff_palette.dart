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
    required this.series,
    required this.seriesAlt,
    required this.marker,
    required this.markerHalo,
  });

  /// Reads the palette from [context]. Throws when the theme carries none.
  static PayoffPalette of(BuildContext context) =>
      Theme.of(context).extension<PayoffPalette>()!;

  /// The break-even rule and its caption.
  ///
  /// **It is not amber.** This field held `#C07A10` from the day it was added
  /// — kept, unused, against the day the payload could say where break-even
  /// was — and the artboard draws the rule in `border/secondary`, a plain
  /// grey. The mock had invented a colour for a line it was drawing without
  /// one, and nothing compared the two until GGU-146 measured it.
  final Color breakEven;

  /// The `y = 0` rule — heavier than a gridline and lighter than the curve.
  final Color zeroBaseline;

  /// Tick labels under the plot. Lighter than `ChartPalette.mutedLabel`,
  /// which the design reserves for figures rather than axis furniture.
  final Color axisLabel;

  /// The wash over the losing side of the break-even.
  ///
  /// Its own token in the kit — `negative/surface` in light, `surface/negative`
  /// in dark — drawn at **80 % opacity**, which is what the alpha here is.
  /// It was `barLoss` at **7 %**: a derivation invented by the mock, an order
  /// of magnitude off, and over a colour the design does not use for this.
  ///
  /// Still pre-composited rather than an alpha applied at the point of use,
  /// for the reason that was always right: a widget reaching for the correct
  /// one would be branching on brightness, which is what a `ThemeExtension`
  /// exists to avoid.
  final Color lossRegion;

  /// The wash over the winning side. See [lossRegion].
  final Color gainRegion;

  /// The first series' line — the payoff being read.
  final Color series;

  /// Every other series'. The artboard's second line is the after-sell
  /// payoff, and its colour is a **raw hex in the kit, bound to no token and
  /// identical in both themes** — which is Miriam's own open note about the
  /// categorical palette, visible in one field.
  final Color seriesAlt;

  /// The dot on the curve at the current price.
  final Color marker;

  /// The ring around it, which is the card's own surface: the design strokes
  /// the dot **inside** its 12 px box, so the fill is 7 px across and the
  /// ring takes the outer 2.5.
  final Color markerHalo;

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
    series,
    seriesAlt,
    marker,
    markerHalo,
  ];

  @override
  PayoffPalette copyWith({
    Color? breakEven,
    Color? zeroBaseline,
    Color? axisLabel,
    Color? lossRegion,
    Color? gainRegion,
    Color? series,
    Color? seriesAlt,
    Color? marker,
    Color? markerHalo,
  }) => PayoffPalette(
    breakEven: breakEven ?? this.breakEven,
    zeroBaseline: zeroBaseline ?? this.zeroBaseline,
    axisLabel: axisLabel ?? this.axisLabel,
    lossRegion: lossRegion ?? this.lossRegion,
    gainRegion: gainRegion ?? this.gainRegion,
    series: series ?? this.series,
    seriesAlt: seriesAlt ?? this.seriesAlt,
    marker: marker ?? this.marker,
    markerHalo: markerHalo ?? this.markerHalo,
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
      series: _lerp(series, other.series, t),
      seriesAlt: _lerp(seriesAlt, other.seriesAlt, t),
      marker: _lerp(marker, other.marker, t),
      markerHalo: _lerp(markerHalo, other.markerHalo, t),
    );
  }

  static Color _lerp(Color a, Color b, double t) => Color.lerp(a, b, t) ?? b;
}
