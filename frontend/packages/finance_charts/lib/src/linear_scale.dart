import 'package:equatable/equatable.dart';
import 'package:finance_charts/src/tick_steps.dart';

/// Maps a continuous value domain onto a pixel range.
///
/// This is d3's `scaleLinear` and nothing more: the one piece of a charting
/// library that is genuinely worth having, ported rather than depended on
/// (ADR-L D-13). It is a pure function, so a chart's vertical placement can be
/// asserted arithmetically instead of eyeballed in a screenshot.
///
/// For a vertical axis pass `rangeMin` as the **bottom** pixel and `rangeMax`
/// as the top one — `LinearScale(rangeMin: height, rangeMax: 0)` — because the
/// canvas' `y` grows downwards while values grow upwards.
class LinearScale extends Equatable {
  /// Creates a scale over an explicit domain and range.
  const LinearScale({
    required this.domainMin,
    required this.domainMax,
    required this.rangeMin,
    required this.rangeMax,
  });

  /// Creates a scale whose domain is rounded outwards to a readable step.
  ///
  /// The headroom above and below the data is therefore a consequence of the
  /// axis ending on a round number, not a padding constant somebody tuned.
  /// [targetCount] is the number of intervals the rounding aims for.
  factory LinearScale.nice({
    required double min,
    required double max,
    required double rangeMin,
    required double rangeMax,
    int targetCount = defaultTargetCount,
  }) {
    final bounds = niceBounds(min: min, max: max, targetCount: targetCount);
    return LinearScale(
      domainMin: bounds.min,
      domainMax: bounds.max,
      rangeMin: rangeMin,
      rangeMax: rangeMax,
    );
  }

  /// The interval count [LinearScale.nice] aims for by default.
  ///
  /// Two, not the customary five. It was read off the design rather than
  /// chosen: the reference waterfall spans 479,675 → 483,685 and is drawn on
  /// a 478,000 → 484,000 axis, which is the rounding a target of two
  /// intervals produces and no other target does
  /// (`specs/frontend/0002`, "How the scale was recovered").
  static const int defaultTargetCount = 2;

  /// The value mapped to [rangeMin].
  final double domainMin;

  /// The value mapped to [rangeMax].
  final double domainMax;

  /// The pixel [domainMin] maps to.
  final double rangeMin;

  /// The pixel [domainMax] maps to.
  final double rangeMax;

  /// Pixels per unit of value. Negative for a vertical axis, where a larger
  /// value is a smaller `y`.
  double get pixelsPerUnit {
    final span = domainMax - domainMin;
    if (span == 0) return 0;
    return (rangeMax - rangeMin) / span;
  }

  /// The pixel position of [value].
  ///
  /// Values outside the domain are extrapolated rather than clamped; a
  /// waterfall never needs clamping because the domain is derived from the
  /// same levels that are drawn.
  double call(double value) => rangeMin + (value - domainMin) * pixelsPerUnit;

  @override
  List<Object?> get props => <Object?>[
    domainMin,
    domainMax,
    rangeMin,
    rangeMax,
  ];
}
