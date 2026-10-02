import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/charts/waterfall_marks.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_tokens.dart';
import 'package:flutter/material.dart';

/// The selected bucket's detail, as the UI Kit's **mobile** card draws it: a
/// full-bleed strip under the chart, identity and sentence on the left, the
/// contribution on the right in the direction's mark.
///
/// Both lines are the backend's. `NVDA · NVIDIA Corp` is `key` and `label`
/// with a separator between them — punctuation, not formatting — and the
/// second line is `buckets[].detail`, a sentence the backend wrote and this
/// prints verbatim.
///
/// The word *Contribution* in front of the figure is `buckets[].delta_label`,
/// which the backend now sends. It was the gap raised as frontend/0028 §6
/// BG-1 and closed by backend spec 0046 OD-4: a Dart constant would not
/// follow the view's `locale` option, so the caption is the backend's like
/// every other word here (N-9).
class AttributionWaterfallDetail extends StatelessWidget {
  /// Creates the detail strip.
  const AttributionWaterfallDetail({required this.step, super.key});

  /// The strip's padding, measured from the UI Kit's mobile card.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(18, 13, 18, 15);

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
          color: AttributionWaterfallTokens.of(context).footerSurface,
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      step.identityLine,
                      style: ChartText.title(palette.title),
                    ),
                    if (detail != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(detail, style: ChartText.chip(palette.mutedLabel)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // The caption sits *above* the figure here rather than beside
              // it, which is the one place this strip departs from the
              // callout: the identity line already owns the left of the row,
              // and a caption inline with the figure would push it out at
              // phone width. Same two strings, same order top to bottom.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (step.deltaLabel case final String label)
                    Text(label, style: ChartText.chip(palette.mutedLabel)),
                  Text(
                    step.valueDisplay,
                    style: ChartText.headlineFigure(
                      palette.labelFor(step.step.kind),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
