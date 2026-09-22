import 'package:finance_app/components/attribution_driver/attribution_driver_model.dart';
import 'package:finance_app/components/attribution_driver/attribution_driver_tile.dart';
import 'package:finance_app/components/attribution_driver/attribution_driver_tokens.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// Renders `attribution.driver.v1` as Flow A's recomposed detail card.
///
/// Measured from the D2 state: radius 16, padding 14, a 12 px gap; a 34×34
/// ticker chip at radius 9; the name at 13.5/500, the caption at 11/400, the
/// contribution at 14/700 on the right; then three tiles 8 px apart. Every
/// string is the backend's, and the contribution's colour is its `trend`.
class AttributionDriverCard extends StatelessWidget {
  /// Creates the card.
  const AttributionDriverCard({required this.data, super.key});

  /// The card's corner radius, measured from the design.
  static const double radius = 16;

  /// The card's padding, measured from the design.
  static const EdgeInsets padding = EdgeInsets.all(14);

  /// What to draw.
  final AttributionDriverData data;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final palette = AttributionDriverTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Header(data: data, tokens: tokens),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final (index, tile) in data.tiles.indexed) ...<Widget>[
                  if (index > 0) const SizedBox(width: 8),
                  Expanded(child: AttributionDriverTile(tile: tile)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data, required this.tokens});

  final AttributionDriverData data;
  final HomeTokens tokens;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      SizedBox(
        width: 34,
        height: 34,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.ticker,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(
              data.symbol,
              style: TextStyle(
                color: tokens.tickerText,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              data.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              data.caption,
              style: TextStyle(
                color: tokens.muted,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      Text(
        data.contributionDisplay,
        style: TextStyle(
          color: AttributionDriverTile.figureColor(tokens, data.trend),
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}
