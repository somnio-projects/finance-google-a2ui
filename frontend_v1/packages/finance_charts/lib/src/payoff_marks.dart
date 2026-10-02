import 'package:finance_charts/src/chart_geometry.dart';
import 'package:finance_charts/src/linear_scale.dart';
import 'package:finance_charts/src/payoff_point.dart';

/// Where a price marker sits on a laid-out payoff chart (GGU-146).
typedef PayoffMark = ({double x, double y});

/// Locates [at] on the curve [points] describe, or null when it is off it.
///
/// The `y` is **interpolated between the two points either side**, not
/// snapped to the nearer one: the backend samples the curve on a grid of its
/// own choosing and a marker at the current price almost never lands on a
/// sample. Snapping would put the dot visibly off the line it belongs to.
///
/// Returns null when [at] is outside the sampled range, which is the honest
/// answer — a marker beyond the plotted prices has no position on this chart
/// and the caller draws nothing rather than pinning it to an edge.
PayoffMark? payoffMark({
  required List<PayoffPoint> points,
  required double at,
  required LinearScale priceScale,
  required LinearScale valueScale,
}) {
  if (points.isEmpty) return null;
  if (at < points.first.at || at > points.last.at) return null;
  for (var i = 0; i < points.length - 1; i++) {
    final left = points[i];
    final right = points[i + 1];
    if (at < left.at || at > right.at) continue;
    final span = right.at - left.at;
    final t = span == 0 ? 0.0 : (at - left.at) / span;
    final value = left.value + (right.value - left.value) * t;
    return (x: priceScale(at), y: valueScale(value));
  }
  final last = points.last;
  return (x: priceScale(last.at), y: valueScale(last.value));
}

/// The two regions a break-even splits a plot into.
typedef PayoffZones = ({ChartRect loss, ChartRect gain});

/// Everything a break-even and a current price add to a laid-out chart.
typedef PayoffMarkings = ({
  PayoffMark? breakEven,
  PayoffMark? current,
  ChartRect loss,
  ChartRect gain,
});

/// Splits a [width] × [height] plot at [x].
///
/// Vertical, which is the whole point: the design shades *by how far the
/// underlying moved*, so the boundary is a price, not the zero of the value
/// axis. [leftIsLoss] says which side is which.
PayoffZones payoffZones({
  required double x,
  required double width,
  required double height,
  required bool leftIsLoss,
}) {
  final clamped = x < 0 ? 0.0 : (x > width ? width : x);
  final left = ChartRect(left: 0, top: 0, right: clamped, bottom: height);
  final right = ChartRect(left: clamped, top: 0, right: width, bottom: height);
  return leftIsLoss ? (loss: left, gain: right) : (loss: right, gain: left);
}

/// Places both markers on [points] and splits the plot between them.
///
/// Which side loses is read from the curve's **own sign at its lowest
/// price**, so a sale mirrors without a flag travelling down from the
/// payload. With no break-even — a payload that carries no marker — the
/// split falls back to above and below [zeroY], which is what every payoff
/// chart drew before GGU-146.
PayoffMarkings payoffMarkings({
  required List<PayoffPoint> points,
  required double width,
  required double height,
  required double zeroY,
  required LinearScale priceScale,
  required LinearScale valueScale,
  double? breakEvenAt,
  double? currentAt,
}) {
  PayoffMark? mark(double? at) => at == null
      ? null
      : payoffMark(
          points: points,
          at: at,
          priceScale: priceScale,
          valueScale: valueScale,
        );
  final breakEven = mark(breakEvenAt);
  final current = mark(currentAt);
  if (breakEven == null) {
    return (
      breakEven: null,
      current: current,
      loss: ChartRect(left: 0, top: zeroY, right: width, bottom: height),
      gain: ChartRect(left: 0, top: 0, right: width, bottom: zeroY),
    );
  }
  final zones = payoffZones(
    x: breakEven.x,
    width: width,
    height: height,
    leftIsLoss: points.isEmpty || points.first.value < 0,
  );
  return (
    breakEven: breakEven,
    current: current,
    loss: zones.loss,
    gain: zones.gain,
  );
}
