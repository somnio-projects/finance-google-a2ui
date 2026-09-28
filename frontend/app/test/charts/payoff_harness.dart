import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/charts/payoff_chart.dart';
import 'package:finance_app/charts/payoff_painter.dart';
import 'package:finance_app/charts/payoff_tokens.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// A three-point curve that crosses zero in the middle.
///
/// Small enough that a coordinate can be reasoned about by hand, and it still
/// exercises both regions: one sample below zero, one on it, one above.
const List<PayoffPoint> samplePoints = <PayoffPoint>[
  PayoffPoint(at: 100, value: -150),
  PayoffPoint(at: 150, value: 0),
  PayoffPoint(at: 200, value: 150),
];

/// The backend-formatted tick labels that go with [samplePoints].
const List<String> sampleLabels = <String>[r'$100.00', r'$150.00', r'$200.00'];

/// The plot height the painter suite draws at — the design's own.
const double samplePlotHeight = 226;

/// The backend-written rungs that go with [samplePoints].
const List<double> sampleTicks = <double>[-150, 0, 150];

/// Their `display` strings, which the painter prints and never writes.
const List<String> sampleRungLabels = <String>[r'-$150', r'$0', r'+$150'];

/// Builds a painter over [series], so a test varies one thing at a time.
///
/// Extracted rather than repeated: the painter takes a dozen arguments and a
/// suite that spells all of them out per test is a suite where two cases
/// quietly stop agreeing.
PayoffPainter buildPainter({
  List<List<PayoffPoint>> series = const <List<PayoffPoint>>[samplePoints],
  List<String> labels = sampleLabels,
  double width = 400,
  double plotHeight = samplePlotHeight,
  Brightness brightness = Brightness.light,
  List<String> valueLabels = sampleRungLabels,
  List<double> valueTicks = sampleTicks,
  double gutter = 40,
  double? breakEvenAt = 150,
  double? currentAt = 150,
  String breakEvenLabel = r'Break-even $150.00',
  String lossWord = 'Loss',
  String gainWord = 'Gain',
}) => PayoffPainter(
  layout: PayoffLayout.of(
    series: series,
    width: width - gutter,
    height: plotHeight,
    valueTicks: valueTicks,
    breakEvenAt: breakEvenAt,
    currentAt: currentAt,
  ),
  palette: ChartTokens.forBrightness(brightness),
  payoffPalette: PayoffTokens.forBrightness(brightness),
  tickLabels: labels,
  textDirection: TextDirection.ltr,
  plotHeight: plotHeight,
  valueLabels: valueLabels,
  gutter: gutter,
  topBand: PayoffChart.topBand,
  breakEvenLabel: breakEvenLabel,
  lossWord: lossWord,
  gainWord: gainWord,
);

/// Pumps [painter] on a canvas, so a paint pass runs for real.
Widget paintedBy(PayoffPainter painter, {double width = 400}) => Directionality(
  textDirection: TextDirection.ltr,
  child: CustomPaint(
    size: Size(width, samplePlotHeight + 36),
    painter: painter,
  ),
);
