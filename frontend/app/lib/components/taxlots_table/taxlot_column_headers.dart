import 'package:finance_app/components/taxlots_table/taxlot_columns.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:finance_app/components/taxlots_table/taxlot_type.dart';
import 'package:flutter/material.dart';

/// The column captions, on the same grid as the rows below them.
///
/// **Two of the five come from the payload.** The contract gives no per-lot
/// labels, but its top-level `cost_basis.label` and `proceeds.label` name
/// exactly those two columns' quantity, and the view declares a `locale`
/// option — so a Dart constant there would be client-authored copy that
/// silently ignores it, which is the argument this component already wins
/// for a row's term label and for the footer's pills (N-1, OD-5).
///
/// The other three have no payload label and stay client-authored. Two of
/// them deliberately do **not** match the artboard: `Gain / loss` where the
/// design says *Unrealized*, because these are lots the sale consumes and
/// the figure beside them is realised. Spec `frontend/0003` OD-7 is where
/// that wording goes back to design.
class TaxLotColumnHeaders extends StatelessWidget {
  /// Creates the header line.
  const TaxLotColumnHeaders({
    required this.costBasisLabel,
    required this.proceedsLabel,
    super.key,
  });

  /// The payload's `cost_basis.label`.
  final String costBasisLabel;

  /// The payload's `proceeds.label`.
  final String proceedsLabel;

  /// The three captions the contract does not supply, in design order.
  static const String acquired = 'Acquired';

  /// The gain/loss column's caption (OD-7).
  static const String gainLoss = 'Gain / loss';

  /// The holding-period column's caption.
  static const String term = 'Term';

  @override
  Widget build(BuildContext context) {
    final style = TaxLotType.columnHeader(TaxLotPalette.of(context).mutedText);
    // The design right-aligns the three money columns and leaves the date
    // and the term flush left.
    final captions = <(String, TextAlign)>[
      (acquired, TextAlign.left),
      (costBasisLabel, TextAlign.right),
      (proceedsLabel, TextAlign.right),
      (gainLoss, TextAlign.right),
      (term, TextAlign.left),
    ];
    return Padding(
      padding: TaxLotMetrics.columnHeaderPadding,
      child: TaxLotColumns(
        leading: const SizedBox.shrink(),
        cells: <Widget>[
          for (final (caption, align) in captions)
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: align,
              style: style,
            ),
        ],
      ),
    );
  }
}
