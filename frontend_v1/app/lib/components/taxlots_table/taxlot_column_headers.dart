import 'package:finance_app/components/taxlots_table/taxlot_columns.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:finance_app/components/taxlots_table/taxlot_type.dart';
import 'package:flutter/material.dart';

/// The six column captions, on the same grid as the rows below them.
///
/// **Two of the six come from the payload.** The contract gives no per-lot
/// captions, but its top-level `cost_basis.label` and `proceeds.label` name
/// exactly those two columns' quantity, and the view declares a `locale`
/// option — so a Dart constant there would be client-authored copy that
/// silently ignores it (N-1, spec `frontend/0027` OD-1).
///
/// The other four have no payload label and stay client-authored. Two of them
/// deliberately do **not** match the artboard:
///
/// - the kit says *Market value*; this prints `proceeds.label`, because
///   `proceeds` is the field that carries the figure and naming it anything
///   else would be this client narrating the payload (OD-1);
/// - the kit says *Unrealized*; this says [gainLoss], because these are lots
///   a sale consumes and the figure beside the caption is realised
///   (`frontend/0003` OD-7, carried forward).
class TaxLotColumnHeaders extends StatelessWidget {
  /// Creates the caption line.
  const TaxLotColumnHeaders({
    required this.costBasisLabel,
    required this.proceedsLabel,
    super.key,
  });

  /// The payload's `cost_basis.label`.
  final String costBasisLabel;

  /// The payload's `proceeds.label`, over the *Market value* column.
  final String proceedsLabel;

  /// The acquisition column's caption.
  static const String acquired = 'Acquired';

  /// The quantity column's caption.
  static const String shares = 'Shares';

  /// The gain/loss column's caption.
  static const String gainLoss = 'Gain / loss';

  /// The term column's caption, which is the kit's own words even though
  /// the duration under it is missing (OD-2).
  static const String holdingPeriod = 'Holding period';

  @override
  Widget build(BuildContext context) {
    final style = TaxLotType.caption(TaxLotPalette.of(context).mutedText);
    final captions = <String>[
      acquired,
      shares,
      costBasisLabel,
      proceedsLabel,
      gainLoss,
      holdingPeriod,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: TaxLotMetrics.captionGap),
      child: TaxLotColumns(
        leading: const SizedBox.shrink(),
        cells: <Widget>[
          for (final (index, caption) in captions.indexed)
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TaxLotMetrics.columnAlign[index],
              style: style,
            ),
        ],
      ),
    );
  }
}
