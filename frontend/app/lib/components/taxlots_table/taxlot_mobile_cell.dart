import 'package:finance_app/components/taxlots_table/taxlot_figure.dart';
import 'package:finance_app/components/taxlots_table/taxlot_mobile_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlot_type.dart';
import 'package:flutter/material.dart';

/// One caption-over-figure cell of the phone card's four-cell grid.
///
/// [trend] is `null` for the three neutral figures and carries the payload's
/// enum for the gain/loss one, which is the only cell whose colour is a
/// decision. Passing the enum rather than a `Color` keeps that decision in
/// one place: a caller cannot hand this widget green for a loss.
class TaxLotMobileCell extends StatelessWidget {
  /// Creates a cell.
  const TaxLotMobileCell({
    required this.caption,
    required this.value,
    required this.palette,
    this.trend,
    super.key,
  });

  /// The caption, either a server label or one of the two the contract does
  /// not supply.
  final String caption;

  /// The figure, verbatim from its `*.display` string.
  final String value;

  /// The palette this card is drawn with.
  final TaxLotPalette palette;

  /// The payload's `trend`, on the gain/loss cell only.
  final TaxLotTrend? trend;

  @override
  Widget build(BuildContext context) {
    // The lookup lives on the enum (`TaxLotTrendPalette`), so this cell and
    // the desktop row cannot answer the same question differently.
    final valueColor = trend?.colorFor(palette) ?? palette.primaryText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TaxLotType.mobileCaption(palette.mutedText),
        ),
        const SizedBox(height: TaxLotMobileMetrics.captionGap),
        // Scaled to fit, never cut: an ellipsis on a figure prints a number
        // the payload never sent (GGU-148).
        TaxLotFigure(
          value,
          style: trend == null
              ? TaxLotType.cell(valueColor)
              : TaxLotType.cellAccent(valueColor),
        ),
      ],
    );
  }
}
