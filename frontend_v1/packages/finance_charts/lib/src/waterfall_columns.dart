import 'package:finance_charts/src/band_scale.dart';
import 'package:finance_charts/src/chart_geometry.dart';

/// The whole vertical column of band [index], floor to ceiling.
///
/// The UI Kit's selected state tints the band a bar stands in rather than
/// outlining the bar, so the shape it needs is the band's full extent and not
/// the bar's rectangle. It is geometry — two multiplications against
/// [BandScale.bandWidth] — so it is asserted arithmetically here rather than
/// eyeballed in a golden (ADR-L D-13).
///
/// Returns a zero-width column for a band scale with no bands, which is what
/// [BandScale.bandWidth] already reports: an empty walk has no column to tint
/// and must not divide by its own emptiness.
ChartRect waterfallColumn(
  BandScale band,
  int index, {
  required double height,
}) => ChartRect(
  left: band.bandWidth * index,
  top: 0,
  right: band.bandWidth * (index + 1),
  bottom: height,
);

/// Where a label of [width] starts so it stays inside a plot [plotWidth] wide.
///
/// Centred on [center] when there is room, and pushed back inside the plot
/// when there is not — which is what the design does with the two totals'
/// figures: `$482,915` sits over the closing bar but stops at the plot's
/// right edge instead of running into the card's padding.
///
/// A label **wider than the whole plot** is pinned to the left edge rather
/// than given a negative start: at that width nothing can be centred, and a
/// negative offset would push the beginning of the figure off screen, which
/// is the one part a reader needs (the currency and the sign).
double clampedLabelLeft({
  required double center,
  required double width,
  required double plotWidth,
}) {
  if (width >= plotWidth) return 0;
  final ideal = center - width / 2;
  if (ideal < 0) return 0;
  final overshoot = ideal + width - plotWidth;
  return overshoot > 0 ? ideal - overshoot : ideal;
}

/// Where a box of [height] starts so that it sits [gap] above [barTop] and
/// still fits inside a plot [plotHeight] tall.
///
/// The vertical half of [clampedLabelLeft], and the one that is **not**
/// decorative: the desktop callout is anchored on a bar, and a bar near the
/// top of the walk leaves less room above it than the callout needs. Without
/// this the callout is laid out at a negative `y` and the card's `ClipRRect`
/// slices its first line off — measured at ≈10 px on a walk whose peak bar
/// tops out 38 px down (spec frontend/0028 OD-4).
///
/// It **clamps rather than flips**. Pushed down to the plot's ceiling the
/// callout overlaps the top of its own bar, which still reads as belonging to
/// it — its pointer is still aimed at that bar's centre. Flipping it below
/// the bar would need a second pointer direction and a second artboard, and
/// the design has neither.
///
/// A box taller than the whole plot starts at the ceiling too: there is no
/// position that fits, and the top of a callout is the half that carries the
/// name of what was tapped.
double clampedOverlayTop({
  required double barTop,
  required double height,
  required double gap,
  required double plotHeight,
}) {
  if (height >= plotHeight) return 0;
  final ideal = barTop - gap - height;
  return ideal < 0 ? 0 : ideal;
}
