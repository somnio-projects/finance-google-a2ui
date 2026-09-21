import 'package:equatable/equatable.dart';
import 'package:finance_charts/src/chart_geometry.dart';
import 'package:finance_charts/src/linear_scale.dart';
import 'package:finance_charts/src/payoff_axes.dart';
import 'package:finance_charts/src/payoff_point.dart';
import 'package:finance_charts/src/tick_steps.dart';

/// The complete geometry of a payoff chart: *(series, size) → paths*.
///
/// The same bargain as `WaterfallLayout`: everything a painter needs and
/// nothing it can decide, so the chart's correctness is asserted
/// arithmetically rather than only compared against a raster (ADR-L D-13).
///
/// The price axis maps the data's own range edge to edge — a payoff curve is
/// sampled on a grid the backend chose, and rounding that outwards would
/// leave the line floating short of the plot. The value axis *is* rounded
/// outwards, so the chart has headroom and its gridlines land on round
/// numbers.
class PayoffLayout extends Equatable {
  const PayoffLayout._({
    required this.paths,
    required this.gridLines,
    required this.zeroY,
    required this.zeroInDomain,
    required this.lossRegion,
    required this.gainRegion,
    required this.priceScale,
    required this.valueScale,
  });

  /// Lays [series] out across a plot of [width] × [height] pixels.
  ///
  /// [targetTickCount] is **5**, not the waterfall's 2: a payoff curve is
  /// read for *where* it crosses zero and how steeply, which wants a denser
  /// ladder than a five-bar walk. The design draws five labelled gridlines.
  ///
  /// A payload whose `series` or `points` is empty is not an error — the
  /// contract defaults `series` to `[]` — so it lays out a bare plot whose
  /// zero sits on the floor, rather than throwing.
  factory PayoffLayout.of({
    required List<List<PayoffPoint>> series,
    required double width,
    required double height,
    int targetTickCount = defaultTargetTickCount,
  }) {
    final points = <PayoffPoint>[for (final line in series) ...line];
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
    final zero = payoffZero(value, valueScale, height);
    final zeroY = zero.y;
    return PayoffLayout._(
      paths: <List<ChartPoint>>[
        for (final line in series)
          if (line.isNotEmpty)
            <ChartPoint>[
              for (final point in line)
                ChartPoint(priceScale(point.at), valueScale(point.value)),
            ],
      ],
      gridLines: empty ? const <double>[] : payoffGridLines(value, valueScale),
      zeroY: zeroY,
      zeroInDomain: zero.inDomain && !empty,
      lossRegion: ChartRect(left: 0, top: zeroY, right: width, bottom: height),
      gainRegion: ChartRect(left: 0, top: 0, right: width, bottom: zeroY),
      priceScale: priceScale,
      valueScale: valueScale,
    );
  }

  /// The interval count [PayoffLayout.of] aims for by default.
  static const int defaultTargetTickCount = 5;

  /// One polyline per non-empty series, in the order the backend sent them
  /// (N-10).
  final List<List<ChartPoint>> paths;

  /// The `y` of each horizontal gridline.
  ///
  /// Carries no labels: every figure on screen is a backend `*Display`
  /// string, and an axis tick would have to be formatted here (N-1). Spec
  /// `frontend/0005` OD-8 carries the field that would let them be drawn.
  final List<double> gridLines;

  /// The `y` of zero on the value axis — the baseline, and the split between
  /// the two regions. A constant of the scale, never a crossing searched for,
  /// and clamped into the plot so the regions stay well formed.
  final double zeroY;

  /// Whether zero is actually inside the value domain — `false` for an
  /// all-positive or all-negative curve, where [zeroY] is the clamped edge
  /// rather than a real position. See `payoffZero`.
  final bool zeroInDomain;

  /// Everything below zero, shaded as loss.
  final ChartRect lossRegion;

  /// Everything above zero, shaded as gain.
  final ChartRect gainRegion;

  /// The price axis this layout used.
  final LinearScale priceScale;

  /// The value axis this layout used.
  final LinearScale valueScale;

  /// The `x` of the point at [index] of the series at [seriesIndex], or
  /// `null` when either is out of range — which is how the painter asks where
  /// to put a tick label without reaching into [paths].
  double? tickX(int index, {int seriesIndex = 0}) {
    if (seriesIndex < 0 || seriesIndex >= paths.length) return null;
    final line = paths[seriesIndex];
    if (index < 0 || index >= line.length) return null;
    return line[index].x;
  }

  @override
  List<Object?> get props => <Object?>[
    paths,
    gridLines,
    zeroY,
    zeroInDomain,
    lossRegion,
    gainRegion,
    priceScale,
    valueScale,
  ];
}
