import 'package:finance_app/charts/chart_tokens.dart';
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

/// Builds a painter over [series], so a test varies one thing at a time.
///
/// Extracted rather than repeated: the painter takes six arguments and a
/// suite that spells all six out per test is a suite where two cases quietly
/// stop agreeing.
PayoffPainter buildPainter({
  List<List<PayoffPoint>> series = const <List<PayoffPoint>>[samplePoints],
  List<String> labels = sampleLabels,
  double width = 400,
  double plotHeight = samplePlotHeight,
  Brightness brightness = Brightness.light,
}) => PayoffPainter(
  layout: PayoffLayout.of(series: series, width: width, height: plotHeight),
  palette: ChartTokens.forBrightness(brightness),
  payoffPalette: PayoffTokens.forBrightness(brightness),
  tickLabels: labels,
  textDirection: TextDirection.ltr,
  plotHeight: plotHeight,
);

/// Pumps [painter] on a canvas, so a paint pass runs for real.
Widget paintedBy(PayoffPainter painter, {double width = 400}) => Directionality(
  textDirection: TextDirection.ltr,
  child: CustomPaint(
    size: Size(width, samplePlotHeight + 36),
    painter: painter,
  ),
);
