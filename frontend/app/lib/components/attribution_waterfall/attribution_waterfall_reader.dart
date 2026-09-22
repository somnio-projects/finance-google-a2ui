import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

/// The synthetic keys of the two totals — never matched by shape: the card
/// decides drillability from the step's `kind`, a sealed enum.
const String startKey = ':start';

/// See [startKey].
const String endKey = ':end';

/// Reads an `attribution.waterfall.v1` payload into the model the card draws.
///
/// Split out of the component under the 150-line budget when GGU-100 added
/// the headline and the per-step figures. Field paths are literals from the
/// backend's generated catalog entry (`contract-binding.md` §5). Every figure
/// is a `*.display` string; the raw `*.amount` members are read **only**
/// through [ViewPayload.geometry], and only to place a bar (N-4).
AttributionWaterfallData readWaterfall(ViewPayload payload) {
  final buckets = payload.rows('buckets');
  return AttributionWaterfallData(
    title: payload.text('title'),
    net: AttributionNet(
      label: payload.text('net.label'),
      amountDisplay: payload.text('net.amount.display'),
      percentDisplay: payload.text('net.percent.display'),
      direction: _directionOf(payload),
    ),
    steps: <AttributionStep>[
      AttributionStep(
        step: WaterfallStep(
          key: startKey,
          kind: WaterfallStepKind.start,
          level: payload.geometry('start.amount.amount'),
        ),
        label: payload.text('start.label'),
        valueDisplay: payload.text('start.amount.display'),
        cumulativeDisplay: payload.text('start.amount.display'),
      ),
      for (final (index, bucket) in buckets.indexed)
        AttributionStep(
          step: WaterfallStep(
            key: bucket.text('key'),
            kind: _kindOf(bucket, index),
            level: bucket.geometry('cumulative.amount'),
          ),
          label: bucket.text('label'),
          valueDisplay: bucket.text('delta.display'),
          cumulativeDisplay: bucket.text('cumulative.display'),
          detail: bucket.text('detail'),
          selectedLabel: bucket.text('selected_label'),
        ),
      AttributionStep(
        step: WaterfallStep(
          key: endKey,
          kind: WaterfallStepKind.total,
          level: payload.geometry('end.amount.amount'),
        ),
        label: payload.text('end.label'),
        valueDisplay: payload.text('end.amount.display'),
        cumulativeDisplay: payload.text('end.amount.display'),
      ),
    ],
    annotations: <AttributionAnnotation>[
      for (final note in payload.rows('annotations'))
        AttributionAnnotation(
          label: note.text('label'),
          text: note.text('text'),
        ),
    ],
  );
}

/// Maps the backend's `direction` enum onto the geometry's kind.
///
/// The colour and the direction of a bar come from this field and never
/// from the sign of a figure. An unknown value is a contract violation
/// rather than a guess: the enum is declared `up / down`, so a third value
/// means the payload and this build disagree (N-3).
WaterfallStepKind _kindOf(ViewPayload bucket, int index) =>
    switch (bucket.text('direction')) {
      'up' => WaterfallStepKind.gain,
      'down' => WaterfallStepKind.loss,
      // The index is in hand, so the message names the bucket to raise
      // rather than the shape of the path.
      _ => throw PayloadContractException(
        ContractFailure('buckets[$index].direction', 'either "up" or "down"'),
      ),
    };

/// Maps the headline's `net.direction` (`up / down / flat`) onto the enum.
NetDirection _directionOf(ViewPayload payload) =>
    switch (payload.text('net.direction')) {
      'up' => NetDirection.up,
      'down' => NetDirection.down,
      'flat' => NetDirection.flat,
      _ => throw const PayloadContractException(
        ContractFailure('net.direction', 'one of "up", "down", "flat"'),
      ),
    };
