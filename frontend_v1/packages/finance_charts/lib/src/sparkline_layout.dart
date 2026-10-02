import 'package:equatable/equatable.dart';
import 'package:finance_charts/src/chart_geometry.dart';

/// Where a sparkline's values land inside a box (spec 0026).
///
/// The Home hero draws thirty daily values as one line with a fill beneath
/// it. This is the arithmetic and only the arithmetic: values are spread
/// evenly along the width and scaled so the smallest sits on the bottom edge
/// and the largest on the top. The painter in `app/lib/charts/` draws it.
///
/// A flat series has no vertical range to scale into; its points sit at
/// mid-height rather than dividing by zero, which is what a reader expects
/// a flat line to look like.
class SparklineLayout extends Equatable {
  const SparklineLayout._({required this.points, required this.baseline});

  /// Lays [values] out in a `width` by `height` box.
  factory SparklineLayout.of({
    required List<double> values,
    required double width,
    required double height,
  }) {
    if (values.isEmpty || width <= 0 || height <= 0) {
      return SparklineLayout._(points: const <ChartPoint>[], baseline: height);
    }
    var low = values.first;
    var high = values.first;
    for (final value in values) {
      if (value < low) low = value;
      if (value > high) high = value;
    }
    final span = high - low;
    final step = values.length == 1 ? 0.0 : width / (values.length - 1);
    final points = <ChartPoint>[
      for (var index = 0; index < values.length; index++)
        ChartPoint(
          index * step,
          span == 0
              ? height / 2
              : height - (values[index] - low) / span * height,
        ),
    ];
    return SparklineLayout._(points: points, baseline: height);
  }

  /// One point per value, left to right; empty for no values.
  final List<ChartPoint> points;

  /// The y the fill closes down to — the bottom edge of the box.
  final double baseline;

  /// Whether there is anything to draw.
  bool get isEmpty => points.isEmpty;

  @override
  List<Object?> get props => <Object?>[points, baseline];
}
