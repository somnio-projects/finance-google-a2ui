import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_card.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/surface_actions.dart';
import 'package:finance_app/components/view_component.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/widgets.dart';

/// Binds `attribution.waterfall.v1` — what moved a value, step by step.
///
/// Field paths come from the backend's generated catalog entry, and
/// `app/test/architecture/catalog_contract_test.dart` checks this class's
/// [viewId] and [a2uiComponent] against `view-catalog.snapshot.json` so a
/// rename on the backend turns the suite red rather than showing a
/// placeholder on screen.
///
/// Every figure drawn is a `*.display` string. The raw `*.amount` members are
/// read **only** through [ViewPayload.geometry], and only to place a bar —
/// the use ADR-K reserves them for (N-4).
class AttributionWaterfallComponent extends ViewComponent {
  /// Creates the component.
  const AttributionWaterfallComponent();

  @override
  String get viewId => 'attribution.waterfall.v1';

  @override
  String get a2uiComponent => 'AttributionWaterfall';

  /// The one action this surface may send (spec backend/0022 §3.3).
  static const String drillAction = 'drill.attribution.v1';

  @override
  Widget build(BuildContext context, ViewPayload payload) {
    // A tap is a `data` part only inside a scope that wants actions, for a
    // key the payload's own drill declaration lists (frontend/0011 OD-4).
    final scope = SurfaceActions.maybeOf(context);
    final drivers = scope == null ? null : drillableDrivers(payload);
    return AttributionWaterfallCard(
      data: read(payload),
      onSegmentTap: drivers == null
          ? null
          : (key) {
              if (drivers.contains(key)) {
                scope!.onAction(
                  SurfaceActionRequest(
                    action: drillAction,
                    args: <String, String>{'driver': key},
                  ),
                );
              }
            },
    );
  }

  /// The drivers the payload's `drill.attribution.v1` declaration accepts,
  /// or null when the surface declares no drill.
  static Set<String>? drillableDrivers(ViewPayload payload) {
    for (final action in payload.rows('actions')) {
      if (action.text('action') == drillAction) {
        return action.strings('choices').toSet();
      }
    }
    return null;
  }

  /// Reads [payload] into the model the card draws.
  ///
  /// Exposed so the binding can be asserted without a widget tree, and so
  /// the card can be pumped from a literal in a golden test.
  AttributionWaterfallData read(ViewPayload payload) {
    final buckets = payload.rows('buckets');
    return AttributionWaterfallData(
      title: payload.text('title'),
      steps: <AttributionStep>[
        AttributionStep(
          step: WaterfallStep(
            key: _startKey,
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
          ),
        AttributionStep(
          step: WaterfallStep(
            key: _endKey,
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

  /// The synthetic keys of the two totals — never matched by shape: the card
  /// decides drillability from the step's `kind`, a sealed enum.
  static const String _startKey = ':start';
  static const String _endKey = ':end';

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
}

/// Adds this component to [registry].
///
/// Called only from the generated `component_manifest.g.dart`. Every
/// component module exposes exactly one `register`, which is what
/// `binding_rules_test.dart` checks.
void register(ComponentRegistry registry) =>
    registry.register(const AttributionWaterfallComponent());
