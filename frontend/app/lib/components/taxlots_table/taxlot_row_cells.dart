import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:flutter/material.dart';

/// The tick box the design draws at the head of every row.
///
/// **Always empty.** The contract carries no `selectedLotIds` and its
/// catalog entry declares no actions, so nothing can check it — and
/// checking it from `fully_sold` would need a boolean accessor
/// `ViewPayload` does not have. This is the design's own default state;
/// spec `frontend/0003` OD-3 carries what has to arrive before the box
/// becomes an affordance.
class TaxLotCheckBox extends StatelessWidget {
  /// Creates the box.
  const TaxLotCheckBox({super.key});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      width: TaxLotMetrics.checkBoxSize,
      height: TaxLotMetrics.checkBoxSize,
      decoration: BoxDecoration(
        border: Border.all(
          color: TaxLotPalette.of(context).checkboxBorder,
          width: TaxLotMetrics.checkBoxBorderWidth,
        ),
        borderRadius: TaxLotMetrics.checkBoxBorderRadius,
      ),
    ),
  );
}

/// One text cell of a row.
///
/// Always one line: the design's rows are a fixed height and a cell that
/// wrapped would push its neighbours out of alignment. [text] is always a
/// string the backend wrote.
class TaxLotCell extends StatelessWidget {
  /// Creates a cell.
  const TaxLotCell(this.text, {required this.style, this.align, super.key});

  /// The value, verbatim.
  final String text;

  /// The measured type for this column, already tinted with the colour its
  /// role takes — `TaxLotType`'s roles are functions of their colour.
  final TextStyle style;

  /// The design's alignment — right for money, left for the date.
  final TextAlign? align;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: align,
    style: style,
  );
}
