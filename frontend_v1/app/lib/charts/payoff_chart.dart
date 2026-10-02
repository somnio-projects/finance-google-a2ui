import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/charts/payoff_marks_painter.dart';
import 'package:finance_app/charts/payoff_painter.dart';
import 'package:finance_app/charts/payoff_palette.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// A payoff chart: two shaded regions, a labelled value axis, a dashed
/// break-even, one curve per series, a marker at the current price and a
/// price row.
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
    this.valueLabels = const <String>[],
    this.valueTicks = const <double>[],
    this.breakEvenAt,
    this.currentAt,
    this.breakEvenLabel = '',
    this.lossWord = '',
    this.gainWord = '',
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

  /// The band above the plot the break-even's caption is written in.
  static const double topBand = 16;

  /// The gutter kept for the value axis when the payload sends no rungs —
  /// zero, because there is then nothing to write there.
  static const double bareGutter = 0;

  /// One list of points per series, in the order the backend sent them
  /// (N-10). Raw decimals, read only for geometry (ADR-L D-14).
  final List<List<PayoffPoint>> series;

  /// One `points[].label` per point of the first series — the backend's own
  /// formatted prices, drawn verbatim.
  final List<String> tickLabels;

  /// One `value_ticks[].display` per rung, printed beside its rule.
  final List<String> valueLabels;

  /// The profit value each of those rungs sits at (`value_ticks[].amount`),
  /// read only as geometry (ADR-L D-14).
  final List<double> valueTicks;

  /// `markers.break_even.at.amount`, as geometry.
  final double? breakEvenAt;

  /// `markers.current.at.amount`, as geometry.
  final double? currentAt;

  /// What to write above the break-even rule — its label and its price, both
  /// the backend's strings, joined by the caller.
  final String breakEvenLabel;

  /// `zones.loss`.
  final String lossWord;

  /// `zones.gain`.
  final String gainWord;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: topBand + plotHeight + axisBand,
    child: LayoutBuilder(builder: _plot),
  );

  /// The room the widest rung label needs, measured rather than guessed.
  ///
  /// A constant would be wrong in both directions: `$0.00` wastes half of it
  /// and `-$1,250,000.00` overflows it, and the payload decides which arrives
  /// (N-1 — the client never shortens one). Measuring here is a layout pass,
  /// not arithmetic on a figure.
  double _gutter(BuildContext context) {
    if (valueLabels.isEmpty) return bareGutter;
    final style = ChartText.axis(PayoffPalette.of(context).axisLabel);
    final direction = Directionality.of(context);
    var widest = 0.0;
    for (final label in valueLabels) {
      final width = measureLabel(label, style, textDirection: direction).width;
      if (width > widest) widest = width;
    }
    return widest + rungGap;
  }

  Widget _plot(BuildContext context, BoxConstraints constraints) {
    final gutter = _gutter(context);
    final size = Size(constraints.maxWidth, topBand + plotHeight + axisBand);
    return CustomPaint(
      key: plotKey,
      size: size,
      painter: PayoffPainter(
        layout: PayoffLayout.of(
          series: series,
          width: constraints.maxWidth - gutter,
          height: plotHeight,
          valueTicks: valueTicks,
          breakEvenAt: breakEvenAt,
          currentAt: currentAt,
        ),
        palette: ChartPalette.of(context),
        payoffPalette: PayoffPalette.of(context),
        tickLabels: tickLabels,
        textDirection: Directionality.of(context),
        plotHeight: plotHeight,
        valueLabels: valueLabels,
        gutter: gutter,
        topBand: topBand,
        breakEvenLabel: breakEvenLabel,
        lossWord: lossWord,
        gainWord: gainWord,
      ),
    );
  }
}
