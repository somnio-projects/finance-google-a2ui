import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_tokens.dart';
import 'package:flutter/material.dart';

/// The headline pill — *▲ Net +$61,204.05 (+14.51%)* — as the catalog page
/// draws it: 12/500, radius 9, padding 5×10.
///
/// The label and both figures are the backend's, signs included (GGU-100
/// AC-1/AC-2). The client adds the glyph, chosen from `net.direction` and
/// never from a sign, and the space and parentheses between them — layout,
/// not formatting. A gain sits on the measured green fill; a loss or a flat
/// walk keeps the neutral chip fill, because the design measured no other
/// (spec frontend/0014 OD-3).
class AttributionWaterfallPill extends StatelessWidget {
  /// Creates the pill.
  const AttributionWaterfallPill({required this.net, super.key});

  /// The headline to draw.
  final AttributionNet net;

  /// The glyph the design puts before the label for each direction.
  static String glyphFor(NetDirection direction) => switch (direction) {
    NetDirection.up => '▲ ',
    NetDirection.down => '▼ ',
    NetDirection.flat => '',
  };

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final tokens = AttributionWaterfallTokens.of(context);
    final (Color surface, Color text) = switch (net.direction) {
      NetDirection.up => (tokens.pillGainSurface, palette.barGain),
      NetDirection.down => (palette.rule, palette.barLoss),
      NetDirection.flat => (palette.rule, palette.mutedLabel),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          '${glyphFor(net.direction)}${net.label} '
          '${net.amountDisplay} (${net.percentDisplay})',
          style: ChartText.chip(text),
        ),
      ),
    );
  }
}
