import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:flutter/material.dart';

/// The card's plane: surface, radius, lift and padding.
///
/// One widget because the loading state is the same plane with bars on it,
/// and a skeleton drawn on a *different* card is the reflow the skeleton
/// exists to prevent (ADR-L, rule §3b).
///
/// The kit draws **no hairline** here — the earlier artboard's bordered card
/// is gone. What separates the card from the page is a soft shadow, which is
/// the one value in `TaxLotTokens` that could not be read off a fill: it was
/// taken from the export's own shadow ramp and is an approximation, stated
/// here rather than left to look measured.
class TaxLotsTableSurface extends StatelessWidget {
  /// Wraps [child] in the card.
  const TaxLotsTableSurface({required this.child, super.key});

  /// The card's contents.
  final Widget child;

  /// The shadow's blur, from the export's ramp.
  static const double shadowBlur = 18;

  /// Its downward offset.
  static const Offset shadowOffset = Offset(0, 6);

  @override
  Widget build(BuildContext context) {
    final palette = TaxLotPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: TaxLotMetrics.cardBorderRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadow,
            blurRadius: shadowBlur,
            offset: shadowOffset,
          ),
        ],
      ),
      child: Padding(padding: TaxLotMetrics.cardPadding, child: child),
    );
  }
}
