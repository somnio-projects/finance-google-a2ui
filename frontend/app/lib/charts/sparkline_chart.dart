import 'package:finance_app/charts/sparkline_painter.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// The Home hero's thirty-day line (spec 0026 OD-5).
///
/// Takes the raw values the payload carries as `spark[].value.amount` — read
/// through `ViewPayload.geometry`, the one seam ADR-K reserves for turning a
/// figure into a position — and nothing else. No label, no axis, no number is
/// printed here; the hero prints the total and the change above it.
class SparklineChart extends StatelessWidget {
  /// Creates the chart.
  const SparklineChart({
    required this.values,
    required this.color,
    this.height = designHeight,
    super.key,
  });

  /// Where tests find the plot.
  static const Key plotKey = Key('sparkline-plot');

  /// The design's height, at its 350px width.
  static const double designHeight = 52;

  /// The values, oldest first.
  final List<double> values;

  /// The line's colour — the gain hue on the design.
  final Color color;

  /// The plot's height.
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: LayoutBuilder(
      builder: (context, constraints) => CustomPaint(
        key: plotKey,
        size: constraints.biggest,
        painter: SparklinePainter(
          layout: SparklineLayout.of(
            values: values,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
          ),
          color: color,
        ),
      ),
    ),
  );
}
