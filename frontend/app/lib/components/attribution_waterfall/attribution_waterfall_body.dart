import 'package:finance_app/charts/waterfall_chart.dart';
import 'package:finance_app/charts/waterfall_overlay.dart';
import 'package:finance_app/charts/waterfall_selection.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_callout.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_header.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_notes.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_tokens.dart';
import 'package:flutter/material.dart';

/// Everything inside the card's padding: the header, the chart and the notes.
///
/// Split from the card so the card is chrome, selection state and the tap,
/// and this is the layout — the 150-line budget made the split necessary and
/// the seam is a natural one.
class AttributionWaterfallBody extends StatelessWidget {
  /// Creates the body.
  const AttributionWaterfallBody({
    required this.data,
    required this.selectedIndex,
    required this.showCallout,
    this.onSegmentTap,
    super.key,
  });

  /// What to draw.
  final AttributionWaterfallData data;

  /// The selected step's position, or null when nothing is selected.
  final int? selectedIndex;

  /// Whether this card is wide enough for the desktop callout. When it is
  /// not, the detail goes in the footer strip the card draws below.
  final bool showCallout;

  /// Called with a bucket's `key` when the reader taps its band.
  final void Function(String key)? onSegmentTap;

  @override
  Widget build(BuildContext context) {
    final index = selectedIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AttributionWaterfallHeader(title: data.title, net: data.net),
        const SizedBox(height: 14),
        WaterfallChart(
          steps: data.waterfallSteps,
          valueLabels: data.valueDisplays,
          axisLabels: data.axisLabels,
          selection: _selection(context, index),
          overlay: showCallout && index != null
              ? _callout(data.steps[index])
              : null,
          onSegmentTap: onSegmentTap,
        ),
        // N-9: every note the backend attached, under the chart. The UI Kit's
        // card draws none, because the frame's example carries none — a note
        // the payload sends is not the client's to drop (0028 OD-6).
        if (data.annotations.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          AttributionWaterfallNotes(annotations: data.annotations),
        ],
      ],
    );
  }

  WaterfallOverlay _callout(AttributionStep step) => WaterfallOverlay(
    width: AttributionWaterfallCallout.width,
    builder: (context, pointerDx) =>
        AttributionWaterfallCallout(step: step, pointerDx: pointerDx),
  );

  WaterfallSelection? _selection(BuildContext context, int? index) {
    if (index == null) return null;
    final tokens = AttributionWaterfallTokens.of(context);
    final kind = data.steps[index].step.kind;
    return WaterfallSelection(
      index: index,
      barFill: tokens.selectedBarFor(kind),
      column: tokens.columnFor(kind),
    );
  }
}
