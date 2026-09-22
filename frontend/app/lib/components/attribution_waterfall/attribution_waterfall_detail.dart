import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/charts/waterfall_marks.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_pill.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_tokens.dart';
import 'package:flutter/material.dart';

/// The card's title row: the caption on the left, and on the right either the
/// headline pill or — while a bar is selected — the payload's own caption for
/// that bar, *NVDA selected*, exactly as Flow A's D2 state swaps them.
///
/// Both strings on the right are the backend's: the pill binds `net` and the
/// caption binds `buckets[].selected_label` (GGU-100 AC-1/AC-3). The
/// annotations that used to sit here moved under the chart
/// (`AttributionWaterfallNotes`) so the header matches the design without
/// dropping a note (N-9) — spec frontend/0014 OD-2.
class AttributionWaterfallHeader extends StatelessWidget {
  /// Creates the header.
  const AttributionWaterfallHeader({
    required this.title,
    required this.net,
    this.selectedLabel,
    super.key,
  });

  /// The payload's `title`.
  final String title;

  /// The payload's `net`, drawn as the pill when nothing is selected.
  final AttributionNet net;

  /// The selected step's `selected_label`, drawn instead of the pill.
  final String? selectedLabel;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final caption = selectedLabel;
    return Row(
      children: <Widget>[
        Expanded(child: Text(title, style: ChartText.title(palette.title))),
        const SizedBox(width: 12),
        if (caption == null)
          AttributionWaterfallPill(net: net)
        else
          Text(
            caption,
            style: TextStyle(
              color: AttributionWaterfallTokens.of(context).selection,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }
}

/// What the reader sees after tapping a band.
///
/// The design's selected tooltip reads *NVDA · NVIDIA Corp*, then
/// *+4.2% · 90 sh · $1,204.66*, then the contribution. The second line is
/// `buckets[].detail`, a sentence the backend wrote (GGU-100 AC-3); the strip
/// prints it under the label and keeps the contribution and the running total
/// on the right. A total has no detail, and the strip shows none.
class AttributionWaterfallDetail extends StatelessWidget {
  /// Creates the detail strip.
  const AttributionWaterfallDetail({required this.step, super.key});

  /// The selected step.
  final AttributionStep step;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final detail = step.detail;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.rule,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(step.label, style: ChartText.title(palette.title)),
                    if (detail != null) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: ChartText.axis(
                          AttributionWaterfallTokens.of(context).selection,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                step.valueDisplay,
                style: ChartText.chip(palette.labelFor(step.step.kind)),
              ),
              const SizedBox(width: 12),
              Text(
                step.cumulativeDisplay,
                style: ChartText.chip(palette.mutedLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
