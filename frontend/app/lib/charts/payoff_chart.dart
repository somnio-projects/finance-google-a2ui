import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/payoff_painter.dart';
import 'package:finance_app/charts/payoff_palette.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// A payoff chart: a shaded plot, a zero rule, a curve and a tick row.
///
/// Responsive through `LayoutBuilder` and nothing else — the scales recompute
/// from the `Size` the parent gives, and the painter drops any tick label
/// that would collide, so there is no breakpoint to keep in step with a
/// design (ADR-L D-13, spec `frontend/0005` AC-6).
class PayoffChart extends StatelessWidget {
  /// Creates a chart over [series].
  const PayoffChart({
    required this.series,
    required this.tickLabels,
    super.key,
  });

  /// Identifies the painted plot so a test can find it directly.
  static const Key plotKey = Key('payoff-plot');

  /// The plot's height, measured from the design: its artboard runs `y` 18 to
  /// 244 inside a 280-tall viewBox.
  static const double plotHeight = 226;

  /// The band below the plot the tick row is drawn in — the design's 36 px
  /// between the plot floor and the bottom of its viewBox.
  static const double axisBand = 36;

  /// One list of points per series, in the order the backend sent them
  /// (N-10). Raw decimals, read only for geometry (ADR-L D-14).
  final List<List<PayoffPoint>> series;

  /// One `points[].label` per point of the first series — the backend's own
  /// formatted prices, drawn verbatim.
  final List<String> tickLabels;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: plotHeight + axisBand,
    child: LayoutBuilder(builder: _plot),
  );

  Widget _plot(BuildContext context, BoxConstraints constraints) => CustomPaint(
    key: plotKey,
    size: Size(constraints.maxWidth, plotHeight + axisBand),
    painter: PayoffPainter(
      layout: PayoffLayout.of(
        series: series,
        width: constraints.maxWidth,
        height: plotHeight,
      ),
      palette: ChartPalette.of(context),
      payoffPalette: PayoffPalette.of(context),
      tickLabels: tickLabels,
      textDirection: Directionality.of(context),
      plotHeight: plotHeight,
    ),
  );
}
