import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_card.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_component.dart';
import 'package:finance_app/components/order_ticket/order_ticket_card.dart';
import 'package:finance_app/components/order_ticket/order_ticket_changes.dart';
import 'package:finance_app/components/order_ticket/order_ticket_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// The waterfall's `Selected · onSegmentTap` state: the card's own
/// selection, opened on the first bucket the backend sent.
///
/// The key is the model's, read through the component's own binding — no
/// payload path is read here, and nothing is chosen by value (N-10).
class SelectedWaterfallPreview extends StatelessWidget {
  /// Creates the state over the example [payload].
  const SelectedWaterfallPreview({required this.payload, super.key});

  /// The example, verbatim.
  final ViewPayload payload;

  @override
  Widget build(BuildContext context) {
    final data = const AttributionWaterfallComponent().read(payload);
    // steps[0] is the start total; the first bucket, when there is one, is
    // the segment a reader would tap. With no buckets nothing is selected.
    final firstBucket = data.steps.length > 2 ? data.steps[1] : null;
    return AttributionWaterfallCard(
      data: data,
      initialSelectedKey: firstBucket?.step.key,
    );
  }
}

/// The ticket's `Recomputed` state: the backend's re-render of the example
/// with one option changed, the figures that moved marked by the same
/// comparison the Order ticket screen uses. Both payloads are the
/// backend's; this compares display strings for equality and computes
/// nothing (N-2).
class RecomputedTicketPreview extends StatelessWidget {
  /// Creates the state from the example ([before]) and the re-render.
  const RecomputedTicketPreview({
    required this.before,
    required this.after,
    super.key,
  });

  /// The example payload.
  final ViewPayload before;

  /// The re-rendered payload.
  final ViewPayload after;

  @override
  Widget build(BuildContext context) {
    const component = OrderTicketComponent();
    final previous = component.read(before);
    final current = component.read(after);
    return OrderTicketCard(
      data: current,
      changedFigures: changedFigures(previous, current),
    );
  }
}
