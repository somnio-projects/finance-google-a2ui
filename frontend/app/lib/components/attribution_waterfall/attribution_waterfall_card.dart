import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_body.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_callout.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_detail.dart';
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
/// Dispatching the catalog's `drill.attribution.v1` action back to the agent
/// is the component's seam, not this card's, so the callback is exposed and
/// the card does not know what it does.
class AttributionWaterfallCard extends StatefulWidget {
  /// Creates the card.
  const AttributionWaterfallCard({
    required this.data,
    this.onSegmentTap,
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

  /// Called with a bucket's `key` when the reader taps its band.
  final void Function(String key)? onSegmentTap;

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
    final index = _selectedIndex(steps);
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
      ],
    );
  }

  int? _selectedIndex(List<AttributionStep> steps) {
    final key = _selectedKey;
    if (key == null) return null;
    for (var index = 0; index < steps.length; index++) {
      if (steps[index].key == key) return index;
    }
    return null;
  }

  void _handleTap(String key) {
    // A total is not drillable — the contract gives neither endpoint a key,
    // and there is nothing to drill into. Tapping one clears the selection.
    // The test is the step's `kind`, a sealed enum, rather than the spelling
    // of its key: a synthetic-key convention is a rule a reader has to know,
    // and this one is already in the type system.
    final step = _stepFor(key);
    final isBucket =
        step != null &&
        (step.step.kind == WaterfallStepKind.gain ||
            step.step.kind == WaterfallStepKind.loss);
    setState(() => _selectedKey = isBucket && key != _selectedKey ? key : null);
    if (isBucket) widget.onSegmentTap?.call(key);
  }

  AttributionStep? _stepFor(String key) {
    for (final step in widget.data.steps) {
      if (step.key == key) return step;
    }
    return null;
  }
}
