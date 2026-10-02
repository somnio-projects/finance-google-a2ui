import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:flutter/material.dart';

/// The card's title row: the caption on the left, the net on the right.
///
/// The UI Kit prints the net as two of the backend's own strings joined by a
/// middle dot — *`+$3,240 · +0.68%`* — in the direction's mark, level with the
/// title. It is **not** a pill and carries no glyph: the pill, the `▲` and the
/// parentheses the first build drew came from the older catalog page and are
/// gone (spec frontend/0028 OD-1).
///
/// `net.label` is still bound. It is not printed, because the design does not
/// print it, but it opens the row's semantic label so a screen reader hears
/// *Net, +$3,240, +0.68%* rather than two bare figures — a server-written
/// label kept rather than dropped (N-9).
class AttributionWaterfallHeader extends StatelessWidget {
  /// Creates the header.
  const AttributionWaterfallHeader({
    required this.title,
    required this.net,
    super.key,
  });

  /// The payload's `title`.
  final String title;

  /// The payload's `net`.
  final AttributionNet net;

  /// The mark a net of [direction] is drawn in.
  ///
  /// From the declared enum and never from the sign of a figure (N-1). A flat
  /// walk is muted: the design colours a move, and nothing moved.
  static Color markFor(NetDirection direction, ChartPalette palette) =>
      switch (direction) {
        NetDirection.up => palette.barGain,
        NetDirection.down => palette.barLoss,
        NetDirection.flat => palette.mutedLabel,
      };

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final figure = '${net.amountDisplay} · ${net.percentDisplay}';
    return Row(
      children: <Widget>[
        Expanded(child: Text(title, style: ChartText.title(palette.title))),
        const SizedBox(width: 12),
        // One line of the backend's words, which cannot wrap; on a card
        // narrower than the design's (the catalog thumbnail) it scales down
        // rather than overflowing the title. Nothing is truncated.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Semantics(
              label: '${net.label} $figure',
              excludeSemantics: true,
              child: Text(
                figure,
                style: ChartText.headlineFigure(
                  markFor(net.direction, palette),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
