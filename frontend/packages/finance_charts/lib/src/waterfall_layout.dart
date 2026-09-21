import 'package:equatable/equatable.dart';
import 'package:finance_charts/src/band_scale.dart';
import 'package:finance_charts/src/chart_geometry.dart';
import 'package:finance_charts/src/linear_scale.dart';
import 'package:finance_charts/src/waterfall_step.dart';

/// The complete geometry of a waterfall chart: *(steps, size) → paths*.
///
/// Everything a painter needs and nothing it can decide for itself. Keeping
/// this a pure value means the chart's correctness is asserted arithmetically
/// — bar tops, bar heights, connector levels — rather than only compared
/// against a golden image, which tells you *that* something moved but not
/// what (ADR-L D-13).
class WaterfallLayout extends Equatable {
  const WaterfallLayout._({
    required this.bars,
    required this.connectors,
    required this.valueScale,
    required this.bandScale,
  });

  /// Lays [steps] out across a plot of [width] × [height] pixels.
  ///
  /// The value axis spans every step's level, rounded outwards to a readable
  /// step, so the floor and the headroom follow from the data. Totals stand
  /// on the floor; a contribution floats between the running total before it
  /// and the one after it.
  factory WaterfallLayout.of({
    required List<WaterfallStep> steps,
    required double width,
    required double height,
    int targetTickCount = LinearScale.defaultTargetCount,
    double barRatio = BandScale.defaultBarRatio,
    double maxBarWidth = BandScale.defaultMaxBarWidth,
  }) {
    final band = BandScale(
      count: steps.length,
      width: width,
      barRatio: barRatio,
      maxBarWidth: maxBarWidth,
    );
    if (steps.isEmpty) {
      return WaterfallLayout._(
        bars: const <WaterfallBar>[],
        connectors: const <WaterfallConnector>[],
        valueScale: LinearScale.nice(
          min: 0,
          max: 0,
          rangeMin: height,
          rangeMax: 0,
          targetCount: targetTickCount,
        ),
        bandScale: band,
      );
    }
    var min = steps.first.level;
    var max = steps.first.level;
    for (final step in steps) {
      if (step.level < min) min = step.level;
      if (step.level > max) max = step.level;
    }
    final scale = LinearScale.nice(
      min: min,
      max: max,
      rangeMin: height,
      rangeMax: 0,
      targetCount: targetTickCount,
    );
    return WaterfallLayout._(
      bars: _bars(steps, band, scale, height),
      connectors: _connectors(steps, band, scale),
      valueScale: scale,
      bandScale: band,
    );
  }

  /// One bar per step, in the order the backend sent them (N-10).
  final List<WaterfallBar> bars;

  /// One connector between each pair of neighbouring steps.
  final List<WaterfallConnector> connectors;

  /// The value axis this layout used.
  final LinearScale valueScale;

  /// The band axis this layout used.
  final BandScale bandScale;

  @override
  List<Object?> get props => <Object?>[bars, connectors, valueScale, bandScale];

  static List<WaterfallBar> _bars(
    List<WaterfallStep> steps,
    BandScale band,
    LinearScale scale,
    double height,
  ) => <WaterfallBar>[
    for (var index = 0; index < steps.length; index++)
      WaterfallBar(
        index: index,
        step: steps[index],
        rect: ChartRect.between(
          left: band.barLeft(index),
          right: band.barRight(index),
          a: scale(steps[index].level),
          // A total stands on the axis floor; a contribution starts where the
          // previous running total left off. `index == 0` is always a total,
          // so the lookback is never out of range.
          b: _standsOnFloor(steps[index].kind)
              ? height
              : scale(steps[index - 1].level),
        ),
      ),
  ];

  static List<WaterfallConnector> _connectors(
    List<WaterfallStep> steps,
    BandScale band,
    LinearScale scale,
  ) => <WaterfallConnector>[
    for (var index = 0; index < steps.length - 1; index++)
      WaterfallConnector(
        from: ChartPoint(band.center(index), scale(steps[index].level)),
        to: ChartPoint(band.center(index + 1), scale(steps[index].level)),
      ),
  ];

  static bool _standsOnFloor(WaterfallStepKind kind) =>
      kind == WaterfallStepKind.start || kind == WaterfallStepKind.total;
}
