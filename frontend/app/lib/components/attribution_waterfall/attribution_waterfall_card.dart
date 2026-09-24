import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/waterfall_chart.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_detail.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_notes.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_tokens.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// Renders `attribution.waterfall.v1` as the design's card.
///
/// The chrome is the design's, measured: a 16 px radius, a 1 px hairline, and
/// 18/16/18/14 padding. Selection is **local state** — tapping a band marks
/// it, swaps the header's pill for the bar's own *selected* caption and
/// reveals its detail. Dispatching the catalog's `drill.attribution.v1`
/// action back to the agent is the component's seam, not this card's, so the
/// callback is exposed and the card does not know what it does.
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
    final steps = widget.data.steps;
    final selected = _selectedIndex(steps);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AttributionWaterfallCard.radius),
      ),
      child: Padding(
        padding: AttributionWaterfallCard.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AttributionWaterfallHeader(
              title: widget.data.title,
              net: widget.data.net,
              selectedLabel: selected == null
                  ? null
                  : steps[selected].selectedLabel,
            ),
            const SizedBox(height: 14),
            WaterfallChart(
              steps: widget.data.waterfallSteps,
              valueLabels: widget.data.valueDisplays,
              axisLabels: widget.data.axisLabels,
              selectedIndex: selected,
              selectionColor: AttributionWaterfallTokens.of(context).selection,
              onSegmentTap: _handleTap,
            ),
            if (selected != null) ...<Widget>[
              const SizedBox(height: 12),
              AttributionWaterfallDetail(step: steps[selected]),
            ],
            if (widget.data.annotations.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              AttributionWaterfallNotes(annotations: widget.data.annotations),
            ],
          ],
        ),
      ),
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
