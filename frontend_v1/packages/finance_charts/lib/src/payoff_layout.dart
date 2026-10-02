import 'package:equatable/equatable.dart';
import 'package:finance_charts/src/chart_geometry.dart';
import 'package:finance_charts/src/linear_scale.dart';
import 'package:finance_charts/src/payoff_axes.dart';
import 'package:finance_charts/src/payoff_marks.dart';
import 'package:finance_charts/src/payoff_point.dart';

/// The complete geometry of a payoff chart: *(series, size) → paths*.
///
/// The same bargain as `WaterfallLayout`: everything a painter needs and
/// nothing it can decide, so correctness is asserted arithmetically rather
/// than only compared against a raster (ADR-L D-13). The frame it is drawn
/// in — both scales and the zero rule — is `payoffFrame`.
class PayoffLayout extends Equatable {
  const PayoffLayout._({
    required this.paths,
    required this.gridLines,
    required this.zeroY,
    required this.zeroInDomain,
    required this.lossRegion,
    required this.gainRegion,
    required this.breakEven,
    required this.current,
    required this.priceScale,
    required this.valueScale,
  });

  /// Lays [series] out across a plot of [width] × [height] pixels.
  ///
  /// An empty `series` is not an error — the contract defaults it to `[]` —
  /// so it lays out a bare plot rather than throwing. [valueTicks] are the
  /// profit values the **backend** chose a rule for; a client picking its
  /// own would be computing a figure it then has to label (N-2). Left empty,
  /// the axis falls back to `niceBounds`' own division. [breakEvenAt] and
  /// [currentAt] are prices from `markers`, placed by path rather than found
  /// by matching a label.
  factory PayoffLayout.of({
    required List<List<PayoffPoint>> series,
    required double width,
    required double height,
    int targetTickCount = defaultTargetTickCount,
    List<double> valueTicks = const <double>[],
    double? breakEvenAt,
    double? currentAt,
  }) {
    final frame = payoffFrame(
      points: <PayoffPoint>[for (final line in series) ...line],
      width: width,
      height: height,
      targetTickCount: targetTickCount,
    );
    final (:value, :priceScale, :valueScale, :zero, :empty) = frame;
    final zeroY = zero.y;
    final first = series.firstWhere(
      (line) => line.isNotEmpty,
      orElse: () => const <PayoffPoint>[],
    );
    final marks = payoffMarkings(
      points: first,
      width: width,
      height: height,
      zeroY: zeroY,
      priceScale: priceScale,
      valueScale: valueScale,
      breakEvenAt: breakEvenAt,
      currentAt: currentAt,
    );
    return PayoffLayout._(
      paths: payoffPaths(series, priceScale, valueScale),
      gridLines: payoffRungs(
        valueTicks: valueTicks,
        bounds: value,
        valueScale: valueScale,
        empty: empty,
      ),
      zeroY: zeroY,
      zeroInDomain: zero.inDomain && !empty,
      lossRegion: marks.loss,
      gainRegion: marks.gain,
      breakEven: marks.breakEven,
      current: marks.current,
      priceScale: priceScale,
      valueScale: valueScale,
    );
  }

  /// The interval count [PayoffLayout.of] aims for by default.
  static const int defaultTargetTickCount = 5;

  /// One polyline per non-empty series, in the order the backend sent them
  /// (N-10).
  final List<List<ChartPoint>> paths;

  /// The `y` of each horizontal gridline, in the order the ticks arrived.
  ///
  /// No labels: since GGU-146 the payload sends one per rung, so a caller
  /// zips this with `value_ticks[]`. Spec `frontend/0005` OD-8 asked for
  /// that field and it now exists.
  final List<double> gridLines;

  /// The `y` of zero — a scale constant, never a crossing searched for.
  final double zeroY;

  /// Whether zero is inside the value domain — false for an all-positive or
  /// all-negative curve, where [zeroY] is a clamped edge (`payoffZero`).
  final bool zeroInDomain;

  /// The side of the break-even the curve loses on.
  final ChartRect lossRegion;

  /// The side it gains on.
  final ChartRect gainRegion;

  /// Where the break-even meets the curve; null when the payload sent no
  /// marker, or it falls outside the plotted range.
  final PayoffMark? breakEven;

  /// Where the current price meets the curve; see [breakEven].
  final PayoffMark? current;

  /// The price axis this layout used.
  final LinearScale priceScale;

  /// The value axis it used.
  final LinearScale valueScale;

  /// The `x` of the point at [index] of the series at [seriesIndex], or null
  /// when either is out of range — how the painter asks where to put a tick
  /// label without reaching into [paths].
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
    breakEven,
    current,
    priceScale,
    valueScale,
  ];
}
