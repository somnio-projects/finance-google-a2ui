import 'package:finance_app/components/taxlots_table/taxlot_check_glyph.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';
import 'package:flutter/material.dart';

/// The mark at the head of a lot the sale consumes whole.
///
/// **It is a state, not a control.** [fullySold] comes from the payload's
/// `lots[].fully_sold`, and the view declares no action and no selection
/// option, so nothing here is tappable (spec `frontend/0027` OD-3). It used
/// to be the kit's square tick box — an empty hairline square on the partial
/// lots — and a square that can be empty or ticked reads as a checkbox that
/// ignores taps (GGU-148). So the mark is round, filled, and drawn **only**
/// for a fully sold lot; a partial lot gets an empty slot of the same size,
/// which keeps the columns aligned and offers nothing to press.
class TaxLotSoldMark extends StatelessWidget {
  /// Creates the mark.
  const TaxLotSoldMark({required this.fullySold, super.key});

  /// Whether the sale consumes this lot whole.
  final bool fullySold;

  /// What a screen reader hears for a fully sold lot.
  static const String tickedLabel = 'fully sold';

  /// …and for one the sale does not consume whole.
  ///
  /// The **negation of the flag**, not a claim beyond it: `fully_sold: false`
  /// says the sale does not consume the lot whole and nothing about what it
  /// does consume. "Partially sold" would be this client asserting the
  /// payload's other half, which is the move OD-1 refuses for *Unrealized*.
  /// These two and the three client captions in `TaxLotColumnHeaders` are the
  /// whole of this component's client-authored English (spec `frontend/0027`
  /// OD-1).
  static const String partialLabel = 'not fully sold';

  /// The sentence a whole row announces, in both layouts.
  ///
  /// It lives here because the mark is the part a reader cannot see: a row
  /// that announced its figures without saying whether the sale consumes it
  /// whole would be the accessible half of the same omission. It is status
  /// text inside the row's label — never a checkbox with a checked state.
  static String rowLabel(TaxLot lot) =>
      '${lot.acquiredOnDisplay} ${lot.unitsDisplay} ${lot.costBasisDisplay} '
      '${lot.proceedsDisplay} ${lot.gainLossDisplay} ${lot.termLabel} '
      '${lot.fullySold ? tickedLabel : partialLabel}';

  @override
  Widget build(BuildContext context) {
    if (!fullySold) {
      return const Align(
        child: SizedBox.square(dimension: TaxLotMetrics.soldMarkSize),
      );
    }
    final palette = TaxLotPalette.of(context);
    return Align(
      child: Container(
        width: TaxLotMetrics.soldMarkSize,
        height: TaxLotMetrics.soldMarkSize,
        decoration: BoxDecoration(
          color: palette.checkedBox,
          shape: BoxShape.circle,
        ),
        child: CustomPaint(
          painter: TaxLotCheckGlyphPainter(color: palette.checkGlyph),
        ),
      ),
    );
  }
}
