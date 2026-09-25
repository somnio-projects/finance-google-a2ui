import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The colours an allocation donut and its legend are drawn with.
///
/// A second `ThemeExtension` beside `ChartPalette` rather than four more
/// fields on it, for two reasons. A **categorical ramp is a different kind of
/// thing** from ten semantic roles: `barGain` means "this went up" and
/// `swatches[2]` means only "the third category, whatever it is". And
/// `chart_palette.dart` is already 141 lines against a 150-line budget, so an
/// eleventh field would have forced a split anyway — better one along the
/// seam that means something.
///
/// Every value is **measured** from the rendered design
/// (`.design-refs/Catalog_HoldingsSummary.dc.html`, served over HTTP — see
/// `specs/frontend/0007` §1c). The literals live in `ChartTokens`, because a
/// colour literal belongs in a `*_tokens.dart` (spec frontend/0029 OD-4).
@immutable
class AllocationPalette extends ThemeExtension<AllocationPalette> {
  /// Creates a palette.
  const AllocationPalette({
    required this.swatches,
    required this.legendWeight,
    required this.legendValue,
    required this.legendDivider,
    this.classSwatches = const <Color>[],
  });

  /// Reads the palette from [context].
  ///
  /// Throws if the theme carries none, deliberately — the same bargain
  /// `ChartPalette.of` makes: a chart drawn in fallback colours looks
  /// plausible and is wrong, which is worse than a loud test failure.
  static AllocationPalette of(BuildContext context) =>
      Theme.of(context).extension<AllocationPalette>()!;

  /// One colour per category, in payload order (N-10).
  ///
  /// The design ships six, which is what its by-sector state needs. The
  /// catalog's `top_n` goes to 20 and `include_other` adds a row on top, so a
  /// payload **can** outrun the ramp — [swatchFor] wraps rather than running
  /// out, and a test pumps 14 categories to prove every one is drawn.
  final List<Color> swatches;

  /// The ramp for the four asset classes — indigo, teal, **grey for cash**,
  /// amber — measured from `Home.dc.html`; the default ramp when empty.
  final List<Color> classSwatches;

  /// A legend row's weight figure, e.g. `59.27%`.
  final Color legendWeight;

  /// A legend row's money figure, e.g. `$38,550.00`.
  final Color legendValue;

  /// The hairline under a legend row.
  final Color legendDivider;

  /// The swatch for the category at [index], wrapping when the ramp runs out.
  ///
  /// Wrapping is the design's own fallback made explicit: it never drew more
  /// than six slices, so there is no eleventh hue to copy, and repeating in
  /// order is the one behaviour that keeps arc *i* and legend row *i* the same
  /// colour whatever the length. Colours repeating is a legibility problem the
  /// legend solves; a category drawn in no colour at all is a missing row.
  Color swatchFor(int index) => swatches[index % swatches.length];

  /// The ramp for [groupBy]: the class ramp for `asset_class`, else default.
  List<Color> rampFor(String groupBy) =>
      groupBy == 'asset_class' && classSwatches.isNotEmpty
      ? classSwatches
      : swatches;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AllocationPalette &&
          listEquals(other.swatches, swatches) &&
          other.legendWeight == legendWeight &&
          other.legendValue == legendValue &&
          other.legendDivider == legendDivider;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(swatches),
    legendWeight,
    legendValue,
    legendDivider,
    classSwatches,
  );

  @override
  AllocationPalette copyWith({
    List<Color>? swatches,
    Color? legendWeight,
    Color? legendValue,
    Color? legendDivider,
    List<Color>? classSwatches,
  }) => AllocationPalette(
    swatches: swatches ?? this.swatches,
    legendWeight: legendWeight ?? this.legendWeight,
    legendValue: legendValue ?? this.legendValue,
    legendDivider: legendDivider ?? this.legendDivider,
    classSwatches: classSwatches ?? this.classSwatches,
  );

  @override
  AllocationPalette lerp(covariant AllocationPalette? other, double t) {
    if (other == null) return this;
    return AllocationPalette(
      swatches: _lerpRamp(swatches, other.swatches, t),
      legendWeight: _lerp(legendWeight, other.legendWeight, t),
      legendValue: _lerp(legendValue, other.legendValue, t),
      legendDivider: _lerp(legendDivider, other.legendDivider, t),
      classSwatches: _lerpRamp(classSwatches, other.classSwatches, t),
    );
  }

  /// Interpolates the ramp pairwise, or snaps when the two differ in length.
  ///
  /// Two ramps of different lengths have no pairwise correspondence to
  /// interpolate, and inventing one would blend the third hue into the
  /// fourth. Snapping at the midpoint is the honest answer, and the case
  /// only arises if a future theme ships a different count.
  static List<Color> _lerpRamp(List<Color> from, List<Color> other, double t) {
    if (other.length != from.length) return t < 0.5 ? from : other;
    return <Color>[
      for (var index = 0; index < from.length; index++)
        _lerp(from[index], other[index], t),
    ];
  }

  /// `Color.lerp` is nullable for nullable inputs; these never are, so this
  /// keeps the call sites above free of `!` (the shape `ChartPalette` uses).
  static Color _lerp(Color a, Color b, double t) => Color.lerp(a, b, t) ?? b;
}
