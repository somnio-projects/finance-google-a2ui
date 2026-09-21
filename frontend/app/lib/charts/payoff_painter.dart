import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/payoff_palette.dart';
import 'package:finance_app/charts/payoff_ticks.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Paints a [PayoffLayout].
///
/// Holds no geometry: every coordinate arrives computed, so what can be wrong
/// here is a colour, a width or a dash, and the arithmetic is proved
/// separately in `finance_charts` (ADR-L D-13). Every string it draws is a
/// backend `*Display` value copied to the canvas (N-1).
class PayoffPainter extends CustomPainter {
  /// Creates a painter for one laid-out chart.
  const PayoffPainter({
    required this.layout,
    required this.palette,
    required this.payoffPalette,
    required this.tickLabels,
    required this.textDirection,
    required this.plotHeight,
  });

  /// A gridline, measured from the design's SVG template.
  static const double gridWidth = 1;

  /// The zero rule, heavier than a gridline (`stroke-width="1.5"`).
  static const double zeroWidth = 1.5;

  /// The curve (`stroke-width="2.6"`, round cap and join).
  static const double curveWidth = 2.6;

  /// The gap between the plot floor and the tick row.
  static const double tickGap = 10;

  /// The geometry to draw.
  final PayoffLayout layout;

  /// The shared chart colours — the curve, the gain and loss marks, the grid.
  final ChartPalette palette;

  /// The three roles specific to a payoff curve.
  final PayoffPalette payoffPalette;

  /// One `points[].label` per point of the first series, in arrival order.
  ///
  /// Backend-formatted prices. The painter chooses **which** of them fit, and
  /// never what any of them says.
  final List<String> tickLabels;

  /// The reading direction the labels are laid out in.
  final TextDirection textDirection;

  /// The height of the plot itself; the tick row is drawn below it.
  final double plotHeight;

  @override
  void paint(Canvas canvas, Size size) {
    _paintRegions(canvas);
    _paintGrid(canvas, size.width);
    _paintCurves(canvas);
    _paintTicks(canvas, size.width);
  }

  @override
  bool shouldRepaint(PayoffPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.palette != palette ||
      oldDelegate.payoffPalette != payoffPalette ||
      oldDelegate.plotHeight != plotHeight ||
      !listEquals(oldDelegate.tickLabels, tickLabels);

  /// Shades gain above the zero rule and loss below it.
  ///
  /// The split is `layout.zeroY`, a constant of the value scale — **not** a
  /// crossing located in the data. The design shades the columns either side
  /// of break-even, which needs a field the payload lacks (spec
  /// `frontend/0005` OD-1).
  void _paintRegions(Canvas canvas) {
    final gain = Paint()..color = payoffPalette.gainRegion;
    final loss = Paint()..color = payoffPalette.lossRegion;
    canvas
      ..drawRect(_rect(layout.gainRegion), gain)
      ..drawRect(_rect(layout.lossRegion), loss);
  }

  static Rect _rect(ChartRect r) =>
      Rect.fromLTRB(r.left, r.top, r.right, r.bottom);

  void _paintGrid(Canvas canvas, double width) {
    final grid = Paint()
      ..color = palette.border
      ..strokeWidth = gridWidth;
    for (final y in layout.gridLines) {
      canvas.drawLine(Offset(0, y), Offset(width, y), grid);
    }
    // No rule when zero is off the plot: `zeroY` is then the clamped edge,
    // and a line there would claim a break-even the curve never reaches.
    if (!layout.zeroInDomain) return;
    canvas.drawLine(
      Offset(0, layout.zeroY),
      Offset(width, layout.zeroY),
      Paint()
        ..color = payoffPalette.zeroBaseline
        ..strokeWidth = zeroWidth,
    );
  }

  void _paintCurves(Canvas canvas) {
    for (final (index, points) in layout.paths.indexed) {
      if (points.isEmpty) continue;
      final path = Path()..moveTo(points.first.x, points.first.y);
      for (final point in points.skip(1)) {
        path.lineTo(point.x, point.y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = index == 0 ? palette.barTotal : palette.barNeutral
          ..style = PaintingStyle.stroke
          ..strokeWidth = curveWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _paintTicks(Canvas canvas, double width) => paintTickRow(
    canvas,
    layout: layout,
    labels: tickLabels,
    color: payoffPalette.axisLabel,
    textDirection: textDirection,
    width: width,
    top: plotHeight + tickGap,
  );
}
