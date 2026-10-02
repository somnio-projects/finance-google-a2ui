import 'package:equatable/equatable.dart';
import 'package:finance_app/components/payoff_chart/payoff_chart_marks.dart';
import 'package:finance_charts/finance_charts.dart';

/// A label/figure pair the backend wrote — a total or an annotation.
///
/// Both halves are strings the backend formatted, and the card draws them
/// verbatim. `payoff.curve.v1` gives `totals[]` a `{label, amount{display}}`
/// and `annotations[]` a `{label, text}`; they are the same thing on screen,
/// so they share one type rather than two that differ by field name.
class PayoffFact extends Equatable {
  /// Creates a fact.
  const PayoffFact({required this.label, required this.text});

  /// The payload's `label`, e.g. `Break-even price`.
  final String label;

  /// The payload's `amount.display` or `text`, already formatted (N-1).
  final String text;

  @override
  List<Object?> get props => <Object?>[label, text];
}

/// One profit-and-loss line, with its name and its per-point labels.
///
/// The geometry travels as [PayoffPoint]s and the strings travel beside them,
/// which is the same split `AttributionStep` uses: nothing in this class is a
/// number that could be formatted.
class PayoffLine extends Equatable {
  /// Creates a line.
  const PayoffLine({
    required this.name,
    required this.points,
    required this.tickLabels,
  });

  /// The payload's `series[].name`.
  final String name;

  /// The geometry, in arrival order (N-10).
  final List<PayoffPoint> points;

  /// The payload's `series[].points[].label` — one formatted price per point.
  final List<String> tickLabels;

  @override
  List<Object?> get props => <Object?>[name, points, tickLabels];
}

/// Everything `payoff.curve.v1` renders.
class PayoffChartData extends Equatable {
  /// Creates the model.
  const PayoffChartData({
    required this.title,
    required this.disclosure,
    required this.totals,
    required this.lines,
    required this.annotations,
    this.rungs = const <PayoffRung>[],
    this.breakEven,
    this.current,
    this.lossWord = '',
    this.gainWord = '',
  });

  /// The payload's `title`.
  final String title;

  /// The payload's `disclosure`, rendered verbatim and never dropped (N-9).
  ///
  /// It is the sentence that stops a straight line being read as an options
  /// payoff — "no strike, no expiry, no implied volatility" — so dropping it
  /// would be a compliance defect, not a layout choice.
  final String disclosure;

  /// The payload's `totals`, in arrival order.
  final List<PayoffFact> totals;

  /// The payload's `series`, in arrival order.
  final List<PayoffLine> lines;

  /// The payload's `annotations`, in arrival order.
  final List<PayoffFact> annotations;

  /// The payload's `value_ticks`, ascending.
  final List<PayoffRung> rungs;

  /// The payload's `markers.break_even`.
  final PayoffMarker? breakEven;

  /// The payload's `markers.current`.
  final PayoffMarker? current;

  /// The payload's `zones.loss` — the word written in the losing region.
  final String lossWord;

  /// The payload's `zones.gain`.
  final String gainWord;

  /// The geometry the chart lays out, one list per series.
  List<List<PayoffPoint>> get series => <List<PayoffPoint>>[
    for (final line in lines) line.points,
  ];

  /// The tick labels of the first series, which is the one the axis is drawn
  /// from. Empty when the payload carried no series at all.
  List<String> get tickLabels =>
      lines.isEmpty ? const <String>[] : lines.first.tickLabels;

  @override
  List<Object?> get props => <Object?>[
    title,
    disclosure,
    totals,
    lines,
    annotations,
    rungs,
    breakEven,
    current,
    lossWord,
    gainWord,
  ];
}
