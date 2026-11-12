import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:flutter/material.dart';

/// The affordance a selected, drillable bucket shows (frontend/0040 AC-2).
///
/// The tap on a bar only selects it; this is what sends. Drawn in the card's
/// flow — under the chart, or under the phone's detail strip — rather than in
/// the desktop callout, which is an overlay inside the chart's own gesture
/// area (OD-2). The colour is the card's selection role, `barTotal`, the one
/// the selected bar is ringed with (frontend/0014 OD-6).
class AttributionWaterfallDrillButton extends StatelessWidget {
  /// Creates the button.
  const AttributionWaterfallDrillButton({
    required this.label,
    required this.step,
    required this.onPressed,
    super.key,
  });

  /// The padding around the button, inside the card's edges.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(10, 0, 10, 8);

  /// The declaration's own words.
  final String label;

  /// The selected bucket, named to a screen reader.
  final AttributionStep step;

  /// Sends the drill.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = ChartPalette.of(context).barTotal;
    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.centerRight,
        child: Semantics(
          button: true,
          label: '$label, ${step.identityLine}',
          excludeSemantics: true,
          child: TextButton.icon(
            onPressed: onPressed,
            style: TextButton.styleFrom(foregroundColor: color),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text(label, style: ChartText.title(color)),
          ),
        ),
      ),
    );
  }
}
