/// Fixtures for the waterfall suites, and mutations of the catalog example.
///
/// The happy path binds the backend's generated example unchanged; the
/// mutations bend one field each so a test can prove the component *raises*
/// rather than reconstructs (N-3). Kept beside the suites that use them
/// rather than copy-pasted into each — a fixture that differs between two
/// halves of a class's tests is how the halves stop agreeing.
library;

import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_charts/finance_charts.dart';

/// A step for the detail suites, shaped like the catalog's NVDA bucket.
AttributionStep fixtureStep(WaterfallStepKind kind, {String? detail}) =>
    AttributionStep(
      step: WaterfallStep(key: 'NVDA', kind: kind, level: 1),
      label: 'NVIDIA Corp',
      valueDisplay: r'$10,230.00',
      cumulativeDisplay: r'$67,155.00',
      detail: detail,
      selectedLabel: 'NVDA selected',
    );

/// A copy of [example] whose first bucket reports [direction].
Map<String, dynamic> withDirection(
  Map<String, dynamic> example,
  String direction,
) {
  final buckets = (example['buckets'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  return <String, dynamic>{
    ...example,
    'buckets': <Map<String, dynamic>>[
      <String, dynamic>{...buckets.first, 'direction': direction},
      ...buckets.skip(1),
    ],
  };
}

/// A copy of [example] whose opening level is not a decimal string.
Map<String, dynamic> withBadLevel(Map<String, dynamic> example) {
  final start = example['start'] as Map<String, dynamic>;
  final amount = start['amount'] as Map<String, dynamic>;
  return <String, dynamic>{
    ...example,
    'start': <String, dynamic>{
      ...start,
      'amount': <String, dynamic>{...amount, 'amount': 'not a decimal'},
    },
  };
}

/// One contribution of a synthetic walk, shaped like a real bucket.
AttributionStep bucket(String key, WaterfallStepKind kind, double level) =>
    AttributionStep(
      step: WaterfallStep(key: key, kind: kind, level: level),
      label: '$key Holdings Incorporated',
      valueDisplay: kind == WaterfallStepKind.gain ? r'+$1,000' : r'-$1,000',
      cumulativeDisplay: r'$100,000',
      detail: r'+1.0% · 10 sh · $100.00',
      selectedLabel: '$key selected',
    );

/// A synthetic walk around [buckets]: an opening total, them, a closing one.
///
/// Every figure is a string the payload would have carried. The edge-case
/// suite builds its shapes from this rather than from the catalog snapshot,
/// because the backend publishes one example and these are the *other*
/// shapes the same contract can produce.
AttributionWaterfallData walk(
  List<AttributionStep> buckets, {
  NetDirection direction = NetDirection.up,
}) => AttributionWaterfallData(
  title: "Today's drivers",
  net: AttributionNet(
    label: 'Net',
    amountDisplay: netAmount(direction),
    percentDisplay: netPercent(direction),
    direction: direction,
  ),
  steps: <AttributionStep>[
    const AttributionStep(
      step: WaterfallStep(
        key: ':start',
        kind: WaterfallStepKind.start,
        level: 100000,
      ),
      label: 'Start',
      valueDisplay: r'$100,000',
      cumulativeDisplay: r'$100,000',
    ),
    ...buckets,
    const AttributionStep(
      step: WaterfallStep(
        key: ':end',
        kind: WaterfallStepKind.total,
        level: 103240,
      ),
      label: 'Now',
      valueDisplay: r'$103,240',
      cumulativeDisplay: r'$103,240',
    ),
  ],
  annotations: const <AttributionAnnotation>[],
);

/// The backend's own signed string for a net moving [direction].
String netAmount(NetDirection direction) => switch (direction) {
  NetDirection.up => r'+$3,240',
  NetDirection.down => r'-$3,240',
  NetDirection.flat => r'$0',
};

/// See [netAmount].
String netPercent(NetDirection direction) => switch (direction) {
  NetDirection.up => '+0.68%',
  NetDirection.down => '-0.68%',
  NetDirection.flat => '0.00%',
};
