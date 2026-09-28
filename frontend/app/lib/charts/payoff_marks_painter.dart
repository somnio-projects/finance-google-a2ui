import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// The furniture the design draws around a payoff curve (GGU-146).
///
/// Its own file because it is the axis and the markers rather than the plot,
/// the same seam `payoff_ticks.dart` already cut for the price row. Every
/// string it draws arrives formatted: the rungs are `value_ticks[].display`,
/// the break-even's caption is `markers.break_even.label` and its price is
/// that marker's `at.display`, and the two region words are `zones.loss` and
/// `zones.gain` (N-1 — none of them is written here).
///
/// The dash pattern is the one measurable thing that is **not** from the
/// payload, and it is design: a break-even is a reference, not a reading, and
/// the artboard draws it broken so it cannot be mistaken for a series.
const double breakEvenDash = 4;

/// The gap between two dashes.
const double breakEvenGap = 4;

/// The break-even rule's width — lighter than a curve, heavier than a grid.
const double breakEvenWidth = 1.5;

/// The radius of the dot on the curve at the current price.
const double currentRadius = 3.5;

/// The halo that lifts that dot off the line it sits on.
const double currentHalo = 2;

/// The clearance kept between a rung's label and the plot's left edge.
const double rungGap = 8;

/// The inset a region word is drawn at, inside its own corner.
const double zoneInset = 6;

/// Draws a dashed vertical rule at [x] over a plot [height] tall.
void paintDashedRule(
  Canvas canvas, {
  required double x,
  required double height,
  required Color color,
}) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = breakEvenWidth;
  for (var y = 0.0; y < height; y += breakEvenDash + breakEvenGap) {
    final end = y + breakEvenDash;
    canvas.drawLine(
      Offset(x, y),
      Offset(x, end > height ? height : end),
      paint,
    );
  }
}

/// Draws the dot marking where the current price meets the curve.
///
/// A halo in the card's own surface colour sits under it, which is what keeps
/// it readable where it lands on the line rather than beside it.
void paintCurrentMark(
  Canvas canvas, {
  required ChartPoint at,
  required Color color,
  required Color halo,
}) {
  final centre = Offset(at.x, at.y);
  canvas
    ..drawCircle(centre, currentRadius + currentHalo, Paint()..color = halo)
    ..drawCircle(centre, currentRadius, Paint()..color = color);
}

/// Writes one rung label to the left of each gridline.
///
/// **In the plot's own coordinates**, so every `x` here is negative: the
/// caller has already translated the canvas by the gutter, and the labels
/// live outside the plot's left edge. Taking a `gutter` argument and
/// subtracting from it counted the same offset twice and put every label
/// inside the wash — visible the first time the card was opened in a browser
/// and invisible to a golden, whose text is a row of em squares anyway.
///
/// A rule with no label is skipped: the two lists come from one payload field
/// and cannot disagree, but a shorter one must not throw.
void paintValueRungs(
  Canvas canvas, {
  required List<double> rungs,
  required List<String> labels,
  required Color color,
  required TextDirection textDirection,
}) {
  for (final (index, label) in labels.indexed) {
    if (index >= rungs.length) return;
    final painter = measureLabel(
      label,
      ChartText.axis(color),
      textDirection: textDirection,
    );
    painter.paint(
      canvas,
      Offset(-rungGap - painter.width, rungs[index] - painter.height / 2),
    );
  }
}

/// Writes a region's word inside its own corner.
///
/// [atTop] puts it against the plot's ceiling and [atStart] against its left
/// edge, so the loss word and the gain word end up in opposite corners the
/// way the artboard draws them.
void paintZoneWord(
  Canvas canvas, {
  required String word,
  required ChartRect region,
  required Color color,
  required TextDirection textDirection,
  required bool atTop,
  required bool atStart,
}) {
  if (word.isEmpty) return;
  final painter = measureLabel(
    word,
    ChartText.axis(color),
    textDirection: textDirection,
  );
  if (region.right - region.left < painter.width + zoneInset * 2) return;
  painter.paint(
    canvas,
    Offset(
      atStart
          ? region.left + zoneInset
          : region.right - zoneInset - painter.width,
      atTop
          ? region.top + zoneInset
          : region.bottom - zoneInset - painter.height,
    ),
  );
}
