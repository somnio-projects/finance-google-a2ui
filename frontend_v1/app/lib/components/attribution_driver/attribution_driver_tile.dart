import 'package:finance_app/components/attribution_driver/attribution_driver_model.dart';
import 'package:finance_app/components/attribution_driver/attribution_driver_tokens.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// One stat tile: label, figure, caption — radius 10, padding 9×10, as the
/// D2 state measures.
///
/// The figure is coloured by the tile's declared trend and prefixed with its
/// glyph; a tile without a trend stays in body text. Nothing here reads a
/// sign out of a string (N-1).
class AttributionDriverTile extends StatelessWidget {
  /// Creates a tile.
  const AttributionDriverTile({required this.tile, super.key});

  /// What to draw.
  final DriverTile tile;

  /// The glyph the design puts before a trending figure.
  static String glyphFor(DriverTrend? trend) => switch (trend) {
    DriverTrend.up => '▲ ',
    DriverTrend.down => '▼ ',
    DriverTrend.flat || null => '',
  };

  /// The colour of a figure with [trend], from the shell's tokens.
  static Color figureColor(HomeTokens tokens, DriverTrend? trend) =>
      switch (trend) {
        DriverTrend.up => tokens.gain,
        DriverTrend.down => tokens.loss,
        DriverTrend.flat || null => tokens.text,
      };

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AttributionDriverTokens.of(context).tile,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              tile.label,
              style: TextStyle(
                color: tokens.muted,
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              '${glyphFor(tile.trend)}${tile.figure}',
              style: TextStyle(
                color: figureColor(tokens, tile.trend),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            Text(
              tile.caption,
              style: TextStyle(
                color: tokens.muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w400,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
