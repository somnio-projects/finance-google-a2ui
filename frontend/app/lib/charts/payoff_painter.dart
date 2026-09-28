import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/payoff_marks_layer.dart';
import 'package:finance_app/charts/payoff_marks_painter.dart';
import 'package:finance_app/charts/payoff_palette.dart';
import 'package:finance_app/charts/payoff_plot_painter.dart';
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
    required this.valueLabels,
    required this.gutter,
    required this.topBand,
    this.breakEvenLabel = '',
    this.lossWord = '',
    this.gainWord = '',
  });

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

  /// One `value_ticks[].display` per rung, in the order the backend sent
  /// them. The painter prints them and never writes one (N-1).
  final List<String> valueLabels;

  /// The band to the left of the plot the rung labels are written in. The
  /// plot is laid out in what is left, so the two cannot overlap.
  final double gutter;

  /// The band above the plot the break-even's caption is written in.
  final double topBand;

  /// `markers.break_even.label` and its price, already joined by the caller.
  final String breakEvenLabel;

  /// `zones.loss` — the word written in the losing region.
  final String lossWord;

  /// `zones.gain`.
  final String gainWord;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width - gutter;
    canvas
      ..save()
      ..translate(gutter, topBand);
    paintValueRungs(
      canvas,
      rungs: layout.gridLines,
      labels: valueLabels,
      color: payoffPalette.axisLabel,
      textDirection: textDirection,
      gutter: gutter,
    );
    paintPayoffRegions(canvas, layout, payoffPalette);
    paintZoneWords(
      canvas,
      layout: layout,
      payoff: payoffPalette,
      loss: lossWord,
      gain: gainWord,
      textDirection: textDirection,
    );
    paintPayoffGrid(
      canvas,
      width,
      layout: layout,
      palette: palette,
      payoffPalette: payoffPalette,
    );
    paintBreakEven(
      canvas,
      layout: layout,
      payoff: payoffPalette,
      plotHeight: plotHeight,
      label: breakEvenLabel,
      textDirection: textDirection,
    );
    paintPayoffCurves(canvas, layout, palette);
    paintCurrent(canvas, layout: layout, palette: palette);
    paintTickRow(
      canvas,
      layout: layout,
      labels: tickLabels,
      color: payoffPalette.axisLabel,
      textDirection: textDirection,
      width: width,
      top: plotHeight + tickGap,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(PayoffPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.palette != palette ||
      oldDelegate.payoffPalette != payoffPalette ||
      oldDelegate.plotHeight != plotHeight ||
      oldDelegate.gutter != gutter ||
      oldDelegate.topBand != topBand ||
      oldDelegate.breakEvenLabel != breakEvenLabel ||
      oldDelegate.lossWord != lossWord ||
      oldDelegate.gainWord != gainWord ||
      !listEquals(oldDelegate.valueLabels, valueLabels) ||
      !listEquals(oldDelegate.tickLabels, tickLabels);
}
