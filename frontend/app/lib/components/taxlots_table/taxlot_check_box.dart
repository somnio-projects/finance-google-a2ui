import 'package:finance_app/components/taxlots_table/taxlot_check_glyph.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';
import 'package:flutter/material.dart';

/// The tick box at the head of every lot.
///
/// **It is a state, not a control.** [ticked] comes from the payload's
/// `lots[].fully_sold` — the lots this sale consumes whole — and the view
/// declares no action and no selection option, so nothing here is tappable
/// and nothing changes it (spec `frontend/0027` OD-3). It is deliberately
/// not a `Checkbox`: Material's carries a tap target, a splash and a
/// disabled colour, and all three would tell a reader this is an affordance.
class TaxLotCheckBox extends StatelessWidget {
  /// Creates the box.
  const TaxLotCheckBox({required this.ticked, super.key});

  /// Whether the sale consumes this lot whole.
  final bool ticked;

  /// What a screen reader hears for a ticked box.
  static const String tickedLabel = 'fully sold';

  /// …and for an empty one.
  ///
  /// The **negation of the flag**, not a claim beyond it: `fully_sold: false`
  /// says the sale does not consume the lot whole and nothing about what it
  /// does consume. "Partially sold" would be this client asserting the
  /// payload's other half, which is the move OD-1 refuses for *Unrealized*.
  /// These two and the four captions in `TaxLotColumnHeaders` are the whole
  /// of this component's client-authored English (spec `frontend/0027` OD-1).
  static const String partialLabel = 'not fully sold';

  /// The sentence a whole row announces, in both layouts.
  ///
  /// It lives here rather than on either tile because the tick is the part a
  /// reader cannot see: the box draws a state with no text in it, and a row
  /// that announced its figures without saying which of them the sale
  /// consumes would be the accessible half of the same omission.
  static String rowLabel(TaxLot lot) =>
      '${lot.acquiredOnDisplay} ${lot.unitsDisplay} ${lot.costBasisDisplay} '
      '${lot.proceedsDisplay} ${lot.gainLossDisplay} ${lot.termLabel} '
      '${lot.fullySold ? tickedLabel : partialLabel}';

  @override
  Widget build(BuildContext context) {
    final palette = TaxLotPalette.of(context);
    return Align(
      child: Container(
        width: TaxLotMetrics.checkBoxSize,
        height: TaxLotMetrics.checkBoxSize,
        decoration: BoxDecoration(
          color: ticked ? palette.checkedBox : null,
          border: ticked
              ? null
              : Border.all(
                  color: palette.checkboxBorder,
                  width: TaxLotMetrics.checkBoxBorderWidth,
                ),
          borderRadius: TaxLotMetrics.checkBoxBorderRadius,
        ),
        child: ticked
            ? CustomPaint(
                painter: TaxLotCheckGlyphPainter(color: palette.checkGlyph),
              )
            : null,
      ),
    );
  }
}
