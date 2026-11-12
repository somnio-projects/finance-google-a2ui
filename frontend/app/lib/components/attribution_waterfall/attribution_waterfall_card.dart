import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_body.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_callout.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_detail.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_drill.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_drill_button.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// Renders `attribution.waterfall.v1` as the UI Kit's card.
///
/// Selection is **local state** — tapping a band marks it and reveals the
/// bucket's own detail. Which *shape* that detail takes is the one breakpoint
/// in this app and it is deliberate: the UI Kit ships two presentations, a
/// footer strip on a phone and a floating callout on a desktop, and no
/// payload field distinguishes them. The threshold is [calloutMinWidth],
/// measured off the two artboards (spec frontend/0028 OD-4).
///
/// **The tap only selects** (spec frontend/0040 AC-1). Drilling is a second,
/// explicit gesture: a selected bucket the [drill] offers shows a button
/// that sends it. A tap that both selected and sent could not be looked at
/// before it was acted on, and its deselecting re-tap drilled again.
class AttributionWaterfallCard extends StatefulWidget {
  /// Creates the card.
  const AttributionWaterfallCard({
    required this.data,
    this.drill,
    this.initialSelectedKey,
    super.key,
  });

  /// The card's corner radius, measured from the design.
  static const double radius = 16;

  /// The card's padding, measured from the design.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(18, 16, 18, 14);

  /// The narrowest card that shows the callout instead of the footer strip.
  ///
  /// The desktop artboard is 642 px of card and the mobile one 362; a callout
  /// is [AttributionWaterfallCallout.width] wide and stops being an
  /// annotation once it covers most of the plot it points into.
  static const double calloutMinWidth = 520;

  /// What to draw.
  final AttributionWaterfallData data;

  /// What a selected bucket may send, or null when nothing is offered.
  final WaterfallDrill? drill;

  /// The bucket selected before any tap, which is how a test and a golden
  /// reach the selected state without driving a gesture.
  final String? initialSelectedKey;

  @override
  State<AttributionWaterfallCard> createState() =>
      _AttributionWaterfallCardState();
}

class _AttributionWaterfallCardState extends State<AttributionWaterfallCard> {
  String? _selectedKey;

  @override
  void initState() {
    super.initState();
    _selectedKey = widget.initialSelectedKey;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final radius = BorderRadius.circular(AttributionWaterfallCard.radius);
    return LayoutBuilder(
      builder: (context, constraints) => DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border),
          borderRadius: radius,
        ),
        // The footer strip runs to the card's edges, so the rounding has to
        // be a clip and not only a border.
        child: ClipRRect(
          borderRadius: radius,
          child: _body(constraints.maxWidth),
        ),
      ),
    );
  }

  Widget _body(double width) {
    final steps = widget.data.steps;
    final index = _indexOf(_selectedKey, steps);
    final wide = width >= AttributionWaterfallCard.calloutMinWidth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: AttributionWaterfallCard.padding,
          child: AttributionWaterfallBody(
            data: widget.data,
            selectedIndex: index,
            showCallout: wide,
            onSegmentTap: _handleTap,
          ),
        ),
        if (!wide && index != null)
          AttributionWaterfallDetail(step: steps[index]),
        if (_drillButton(index) case final Widget button) button,
      ],
    );
  }

  Widget? _drillButton(int? index) {
    final drill = widget.drill;
    if (drill == null || index == null) return null;
    final step = widget.data.steps[index];
    if (!drill.offers(step.key)) return null;
    return AttributionWaterfallDrillButton(
      label: drill.label,
      step: step,
      onPressed: () => drill.send(step.key),
    );
  }

  int? _indexOf(String? key, List<AttributionStep> steps) {
    if (key == null) return null;
    for (var index = 0; index < steps.length; index++) {
      if (steps[index].key == key) return index;
    }
    return null;
  }

  void _handleTap(String key) {
    // A total is not selectable — the contract gives neither endpoint a key,
    // and there is nothing to drill into. Tapping one clears the selection.
    // The test is the step's `kind`, a sealed enum, rather than the spelling
    // of its key: a synthetic-key convention is a rule a reader has to know,
    // and this one is already in the type system.
    final steps = widget.data.steps;
    final index = _indexOf(key, steps);
    final kind = index == null ? null : steps[index].step.kind;
    final isBucket =
        kind == WaterfallStepKind.gain || kind == WaterfallStepKind.loss;
    setState(() => _selectedKey = isBucket && key != _selectedKey ? key : null);
  }
}
