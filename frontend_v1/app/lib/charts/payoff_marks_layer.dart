import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/charts/payoff_marks_painter.dart';
import 'package:finance_app/charts/payoff_palette.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// Draws everything the design adds around the curve, in plot coordinates.
///
/// One call rather than four, so `PayoffPainter` stays a list of passes and
/// this file owns the furniture. The break-even goes down **before** the
/// curves and the current dot **after** them, which is why the caller makes
/// two calls rather than this one doing all of it: a reference line belongs
/// under the reading and a marker on the reading belongs on top.
void paintBreakEven(
  Canvas canvas, {
  required PayoffLayout layout,
  required PayoffPalette payoff,
  required double plotHeight,
  required String label,
  required TextDirection textDirection,
}) {
  final mark = layout.breakEven;
  if (mark == null) return;
  paintDashedRule(
    canvas,
    x: mark.x,
    height: plotHeight,
    color: payoff.breakEven,
  );
  if (label.isEmpty) return;
  final painter = measureLabel(
    label,
    ChartText.axis(payoff.breakEven),
    textDirection: textDirection,
  );
  painter.paint(canvas, Offset(mark.x - painter.width / 2, -painter.height));
}

/// Writes both region words, each in its own corner.
void paintZoneWords(
  Canvas canvas, {
  required PayoffLayout layout,
  required PayoffPalette payoff,
  required String loss,
  required String gain,
  required TextDirection textDirection,
}) {
  paintZoneWord(
    canvas,
    word: loss,
    region: layout.lossRegion,
    color: payoff.axisLabel,
    textDirection: textDirection,
    atTop: true,
    atStart: true,
  );
  paintZoneWord(
    canvas,
    word: gain,
    region: layout.gainRegion,
    color: payoff.axisLabel,
    textDirection: textDirection,
    atTop: false,
    atStart: false,
  );
}

/// Marks the current price on the curve, if the payload placed one.
void paintCurrent(
  Canvas canvas, {
  required PayoffLayout layout,
  required PayoffPalette payoff,
}) {
  final mark = layout.current;
  if (mark == null) return;
  paintCurrentMark(
    canvas,
    at: ChartPoint(mark.x, mark.y),
    color: payoff.marker,
    halo: payoff.markerHalo,
  );
}
