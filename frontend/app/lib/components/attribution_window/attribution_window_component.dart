import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_card.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_drill.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_reader.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/view_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/widgets.dart';

/// Binds `attribution.window.v1` — what moved the portfolio over a window.
///
/// **A second registration, not a second widget.** The backend publishes this
/// under the same A2UI component name as the all-time walk, because it is the
/// same waterfall drawing a different quantity: a holding's move since the
/// window opened, rather than its unrealised profit since it was bought. The
/// card and the reader are reused verbatim — the payload's shape is the one
/// [readWaterfall] already binds, and none of the fields that differ
/// (`opened`, `closed` on a step) are read by it.
///
/// It exists because the agent's `compute_attribution` tool used to attach
/// the all-time view for a question about a window, so a sentence about today
/// appeared above bars about all time (spec `backend/0039`).
///
/// It drills like the all-time walk, through the same [WaterfallDrill]: this
/// was the surface Flow A's question draws, and it used to read no actions,
/// so a tapped bar sent nothing (GGU-161). The backend declares the drill on
/// today's window only (backend/0056 OD-2); a week's walk declares none and
/// draws no button.
class AttributionWindowComponent extends ViewComponent {
  /// Creates the component.
  const AttributionWindowComponent();

  @override
  String get viewId => 'attribution.window.v1';

  @override
  String get a2uiComponent => 'AttributionWaterfall';

  @override
  Widget build(BuildContext context, ViewPayload payload) =>
      AttributionWaterfallCard(
        data: read(payload),
        drill: WaterfallDrill.of(
          context,
          payload,
          action: WaterfallDrill.declaredAction,
        ),
      );

  /// Reads [payload] into the model the card draws.
  ///
  /// Exposed for the same reason the all-time component exposes its own: the
  /// binding is asserted without a widget tree.
  AttributionWaterfallData read(ViewPayload payload) => readWaterfall(payload);
}

/// Adds this component to [registry].
///
/// Called only from the generated `component_manifest.g.dart`.
void register(ComponentRegistry registry) =>
    registry.register(const AttributionWindowComponent());
