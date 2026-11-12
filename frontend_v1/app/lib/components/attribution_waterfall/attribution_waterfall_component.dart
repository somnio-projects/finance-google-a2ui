import 'package:a2ui_v1/a2ui_v1.dart' show drillAttributionAction;
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_card.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_drill.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_reader.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_skeleton.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/view_component.dart';
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
/// the use ADR-K reserves them for (N-4). The reading itself is
/// [readWaterfall]; this class is the seam and the drill.
class AttributionWaterfallComponent extends ViewComponent {
  /// Creates the component.
  const AttributionWaterfallComponent();

  @override
  String get viewId => 'attribution.waterfall.v1';

  @override
  String get a2uiComponent => 'AttributionWaterfall';

  @override
  Widget build(BuildContext context, ViewPayload payload) =>
      AttributionWaterfallCard(
        data: read(payload),
        // A selected bucket offers the drill only inside a scope that wants
        // actions, for a key the payload's own declaration lists
        // (frontend/0011 OD-4, frontend/0040 AC-2).
        drill: WaterfallDrill.of(
          context,
          payload,
          // The v1.0 action name (ADR-M D-7); the payload still declares
          // the drill by its v0.9 id, which WaterfallDrill reads.
          action: drillAttributionAction,
        ),
      );

  @override
  Widget skeleton(BuildContext context) => const AttributionWaterfallSkeleton();

  /// Reads [payload] into the model the card draws.
  ///
  /// Exposed so the binding can be asserted without a widget tree, and so
  /// the card can be pumped from a literal in a golden test.
  AttributionWaterfallData read(ViewPayload payload) => readWaterfall(payload);
}

/// Adds this component to [registry].
///
/// Called only from the generated `component_manifest.g.dart`. Every
/// component module exposes exactly one `register`, which is what
/// `binding_rules_test.dart` checks.
void register(ComponentRegistry registry) =>
    registry.register(const AttributionWaterfallComponent());
