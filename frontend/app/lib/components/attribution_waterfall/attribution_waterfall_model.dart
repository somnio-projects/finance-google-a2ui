import 'package:equatable/equatable.dart';
import 'package:finance_charts/finance_charts.dart';

/// One step of an attribution walk, with everything the card draws.
///
/// The geometry travels as a [WaterfallStep]; the two figures travel as the
/// backend's own `*.display` strings. Nothing here is a number that could be
/// formatted, which is prohibition N-1 made structural rather than
/// remembered — the same shape `HoldingsAllocationRow` uses.
class AttributionStep extends Equatable {
  /// Creates a step.
  const AttributionStep({
    required this.step,
    required this.label,
    required this.valueDisplay,
    required this.cumulativeDisplay,
  });

  /// The geometry half: key, direction and running total.
  final WaterfallStep step;

  /// The payload's `label`, e.g. `Bitcoin` — or a total's own label.
  final String label;

  /// The figure drawn above the bar: `delta.display` for a contribution,
  /// `amount.display` for a total.
  final String valueDisplay;

  /// The running total after this step, as `cumulative.display`.
  final String cumulativeDisplay;

  /// The payload's `key`, which a drill-down action takes as its argument.
  String get key => step.key;

  @override
  List<Object?> get props => <Object?>[
    step,
    label,
    valueDisplay,
    cumulativeDisplay,
  ];
}

/// A note the backend attached to the view.
///
/// Rendered verbatim and never dropped (N-9). The backend sends one per
/// contribution plus a net; the client does not pick among them, because
/// choosing by matching `label == 'Net'` would be the client interpreting a
/// server-supplied string (N-5).
class AttributionAnnotation extends Equatable {
  /// Creates an annotation.
  const AttributionAnnotation({required this.label, required this.text});

  /// The payload's `annotations[].label`.
  final String label;

  /// The payload's `annotations[].text`, already formatted.
  final String text;

  @override
  List<Object?> get props => <Object?>[label, text];
}

/// Everything `attribution.waterfall.v1` renders.
class AttributionWaterfallData extends Equatable {
  /// Creates the model.
  const AttributionWaterfallData({
    required this.title,
    required this.steps,
    required this.annotations,
  });

  /// The payload's `title`.
  final String title;

  /// The walk: the opening total, each contribution, the closing total — in
  /// the order the backend sent them (N-10).
  final List<AttributionStep> steps;

  /// The payload's `annotations`, in arrival order.
  final List<AttributionAnnotation> annotations;

  /// The geometry the chart lays out.
  List<WaterfallStep> get waterfallSteps => <WaterfallStep>[
    for (final step in steps) step.step,
  ];

  /// The figure drawn above each bar.
  List<String> get valueDisplays => <String>[
    for (final step in steps) step.valueDisplay,
  ];

  /// The category name drawn under each band.
  List<String> get axisLabels => <String>[for (final step in steps) step.label];

  @override
  List<Object?> get props => <Object?>[title, steps, annotations];
}
