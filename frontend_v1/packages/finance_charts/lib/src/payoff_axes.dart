import 'package:finance_charts/src/chart_geometry.dart';
import 'package:finance_charts/src/linear_scale.dart';
import 'package:finance_charts/src/payoff_point.dart';
import 'package:finance_charts/src/tick_steps.dart';

/// The extent of a payoff curve in both of its domains.
typedef PayoffBounds = ({
  double minAt,
  double maxAt,
  double minValue,
  double maxValue,
});

/// The smallest box containing every point of every series.
///
/// Split out of `PayoffLayout` to keep that file inside the 150-line budget,
/// and it earns a file anyway: a second chart over the same shape wants the
/// same sweep, and a sweep is far easier to assert as a function than as a
/// step inside a factory.
///
/// [points] must not be empty — a layout with nothing to draw never asks.
PayoffBounds payoffBounds(List<PayoffPoint> points) {
  var minAt = points.first.at;
  var maxAt = points.first.at;
  var minValue = points.first.value;
  var maxValue = points.first.value;
  for (final point in points) {
    if (point.at < minAt) minAt = point.at;
    if (point.at > maxAt) maxAt = point.at;
    if (point.value < minValue) minValue = point.value;
    if (point.value > maxValue) maxValue = point.value;
  }
  return (minAt: minAt, maxAt: maxAt, minValue: minValue, maxValue: maxValue);
}

/// Where the zero rule sits, and whether it is really on the plot.
typedef ZeroLine = ({double y, bool inDomain});

/// Locates zero on a value axis rounded to [bounds], over a plot [height].
///
/// Zero need not be inside the domain: `niceBounds` rounds to the data, so an
/// all-positive or all-negative curve leaves it off the plot entirely. Left
/// unclamped that puts the rule outside the canvas and inverts the gain and
/// loss rects, so the position is clamped and `inDomain` says whether it
/// means anything — a caller draws no rule when it does not, because a line
/// pinned to the boundary asserts a break-even the plot never contains.
ZeroLine payoffZero(NiceBounds bounds, LinearScale scale, double height) {
  final y = scale(0);
  return (
    y: y < 0 ? 0 : (y > height ? height : y),
    inDomain: bounds.min <= 0 && bounds.max >= 0,
  );
}

/// The `y` of every horizontal gridline of an axis rounded to [bounds].
///
/// Walks the domain in whole steps and maps each through [scale], so the
/// lines land on the round numbers `niceBounds` chose rather than on an even
/// division of the pixel height. The half-step slack in the loop's limit is
/// for floating-point drift: `min + n * step` may land a hair under `max`.
List<double> payoffGridLines(NiceBounds bounds, LinearScale scale) {
  final lines = <double>[];
  final limit = bounds.max + bounds.step / 2;
  for (var value = bounds.min; value <= limit; value += bounds.step) {
    lines.add(scale(value));
  }
  return lines;
}

/// The two scales, the rounded value axis and the zero rule of one layout.
typedef PayoffFrame = ({
  NiceBounds value,
  LinearScale priceScale,
  LinearScale valueScale,
  ZeroLine zero,
  bool empty,
});

/// Builds the frame a `PayoffLayout` is drawn in.
///
/// Split out of the factory to keep that file inside the 150-line budget, and
/// it is the same seam as [payoffBounds]: everything here is a function of
/// the data and the box, with nothing the caller can decide.
PayoffFrame payoffFrame({
  required List<PayoffPoint> points,
  required double width,
  required double height,
  required int targetTickCount,
}) {
  final empty = points.isEmpty;
  final bounds = empty
      ? (minAt: 0.0, maxAt: 1.0, minValue: 0.0, maxValue: 0.0)
      : payoffBounds(points);
  final value = niceBounds(
    min: bounds.minValue,
    max: bounds.maxValue,
    targetCount: targetTickCount,
  );
  final priceScale = LinearScale(
    domainMin: bounds.minAt,
    // A single-sample curve has no width; widening by one unit keeps the
    // scale from dividing by zero and draws the point at the left edge.
    domainMax: bounds.maxAt > bounds.minAt ? bounds.maxAt : bounds.minAt + 1,
    rangeMin: 0,
    rangeMax: width,
  );
  final valueScale = LinearScale(
    domainMin: empty ? 0 : value.min,
    domainMax: empty ? 1 : value.max,
    rangeMin: height,
    rangeMax: 0,
  );
  return (
    value: value,
    priceScale: priceScale,
    valueScale: valueScale,
    zero: payoffZero(value, valueScale, height),
    empty: empty,
  );
}

/// Maps every series onto the plot, dropping the lines that carry no points.
List<List<ChartPoint>> payoffPaths(
  List<List<PayoffPoint>> series,
  LinearScale priceScale,
  LinearScale valueScale,
) => <List<ChartPoint>>[
  for (final line in series)
    if (line.isNotEmpty)
      <ChartPoint>[
        for (final point in line)
          ChartPoint(priceScale(point.at), valueScale(point.value)),
      ],
];

/// The `y` of every horizontal rule, from the backend's ladder when it sent
/// one and from the rounded axis when it did not.
List<double> payoffRungs({
  required List<double> valueTicks,
  required NiceBounds bounds,
  required LinearScale valueScale,
  required bool empty,
}) {
  if (empty) return const <double>[];
  if (valueTicks.isEmpty) return payoffGridLines(bounds, valueScale);
  return <double>[for (final tick in valueTicks) valueScale(tick)];
}
