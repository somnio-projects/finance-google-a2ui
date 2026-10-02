import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/charts/waterfall_marks.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_pointer.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_tokens.dart';
import 'package:flutter/material.dart';

/// The selected bucket's detail, as the UI Kit's **desktop** card draws it: a
/// floating card above the tapped bar with a pointer aimed at it.
///
/// Same three strings as the mobile strip and in the same order — identity,
/// the backend's sentence, the contribution — stacked instead of split,
/// because the callout is narrow and the strip is wide.
///
/// [pointerDx] is where the bar's centre falls inside this card, handed down
/// by the chart. It is not always the middle: a callout beside the plot's
/// edge is pushed back inside and still has to point at its own bar.
class AttributionWaterfallCallout extends StatelessWidget {
  /// Creates the callout.
  const AttributionWaterfallCallout({
    required this.step,
    required this.pointerDx,
    super.key,
  });

  /// The callout's width, measured from the desktop artboard.
  ///
  /// Fixed rather than measured at layout time, and that is the reason this
  /// widget exists in this shape: the chart has to know the width to place
  /// the card *and* the pointer in one pass.
  static const double width = 232;

  /// Its corner radius, measured.
  static const double radius = 12;

  /// The selected step.
  final AttributionStep step;

  /// Where the selected bar's centre falls, from this card's left edge.
  final double pointerDx;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final tokens = AttributionWaterfallTokens.of(context);
    final detail = step.detail;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: palette.border),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: tokens.calloutShadow,
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    step.identityLine,
                    style: ChartText.title(palette.title),
                  ),
                  if (detail != null) ...<Widget>[
                    const SizedBox(height: 5),
                    Text(detail, style: ChartText.chip(palette.mutedLabel)),
                  ],
                  const SizedBox(height: 5),
                  _Contribution(step: step),
                ],
              ),
            ),
          ),
          AttributionWaterfallPointer(
            dx: pointerDx,
            fill: palette.surface,
            border: palette.border,
          ),
        ],
      ),
    );
  }
}

/// The kit's `Contribution +$2,980` line: the caption, then the figure.
///
/// The caption is `buckets[].delta_label`, a backend field — a Dart constant
/// would not follow the view's `locale` option (GGU-119 BG-1). A total has
/// none, and then the figure stands alone as it always did.
class _Contribution extends StatelessWidget {
  const _Contribution({required this.step});

  final AttributionStep step;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final label = step.deltaLabel;
    // A `Wrap`, not a `Row`: the caption is a server-supplied string whose
    // length this build does not know — another locale's word for
    // *Contribution* can be half again as long — and the callout's width is
    // fixed at 232 because the chart has to place the pointer in one pass.
    // Wrapping onto a second line is the honest failure; ellipsising a
    // caption or overflowing the card are not.
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (label != null)
          Text(label, style: ChartText.chip(palette.mutedLabel)),
        Text(
          step.valueDisplay,
          style: ChartText.headlineFigure(palette.labelFor(step.step.kind)),
        ),
      ],
    );
  }
}
