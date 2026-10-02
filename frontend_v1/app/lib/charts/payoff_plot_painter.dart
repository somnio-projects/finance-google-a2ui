import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/payoff_palette.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// The plot itself — the washes, the rules and the lines (GGU-146 split it
/// out of `PayoffPainter`, which had grown past the 150-line budget once the
/// design's furniture arrived; the seam is *plot* against *furniture*).

/// A gridline, measured from the design's SVG template.
const double gridWidth = 1;

/// The zero rule, heavier than a gridline (`stroke-width="1.5"`).
const double zeroWidth = 1.5;

/// The curve. **2 px, measured** — it was 2.6, from the mock (GGU-146).
const double curveWidth = 2;

/// Shades the two regions the break-even splits the plot into.
///
/// Vertical since GGU-146, which is what the design draws: the wash says
/// *how far the underlying moved*, so its boundary is a price. It was
/// horizontal — gain above zero, loss below — because spec `frontend/0005`
/// OD-1 recorded that the payload could not say where break-even was.
/// `markers.break_even` now does, so that gap is closed; the old split is
/// still the fallback for a payload carrying no marker at all.
void paintPayoffRegions(
  Canvas canvas,
  PayoffLayout layout,
  PayoffPalette payoffPalette,
) {
  final gain = Paint()..color = payoffPalette.gainRegion;
  final loss = Paint()..color = payoffPalette.lossRegion;
  canvas
    ..drawRect(_rect(layout.gainRegion), gain)
    ..drawRect(_rect(layout.lossRegion), loss);
}

Rect _rect(ChartRect r) => Rect.fromLTRB(r.left, r.top, r.right, r.bottom);

/// Draws the horizontal rules, and the zero baseline when it is on the plot.
void paintPayoffGrid(
  Canvas canvas,
  double width, {
  required PayoffLayout layout,
  required ChartPalette palette,
  required PayoffPalette payoffPalette,
}) {
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

/// Draws one polyline per series, the first in the chart's own accent.
void paintPayoffCurves(
  Canvas canvas,
  PayoffLayout layout,
  PayoffPalette payoff,
) {
  for (final (index, points) in layout.paths.indexed) {
    if (points.isEmpty) continue;
    final path = Path()..moveTo(points.first.x, points.first.y);
    for (final point in points.skip(1)) {
      path.lineTo(point.x, point.y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = index == 0 ? payoff.series : payoff.seriesAlt
        ..style = PaintingStyle.stroke
        ..strokeWidth = curveWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }
}
