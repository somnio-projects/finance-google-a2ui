import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_card.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_reader.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_skeleton.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/surface_actions.dart';
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
/// [readWaterfall]; this class is the seam and the tap.
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
