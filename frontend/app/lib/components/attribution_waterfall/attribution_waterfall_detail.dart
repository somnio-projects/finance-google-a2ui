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
/// **What the design has and the payload does not** is the word *Contribution*
/// in front of the figure. There is no caption field on a bucket, and a Dart
/// constant would not follow the view's `locale` option, so the figure is
/// drawn on its own and the gap is raised (spec frontend/0028 §6, backend
/// gap BG-1).
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
              Text(
                step.valueDisplay,
                style: ChartText.headlineFigure(
                  palette.labelFor(step.step.kind),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
