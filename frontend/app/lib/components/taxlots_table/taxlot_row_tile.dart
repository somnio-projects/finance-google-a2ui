import 'package:finance_app/components/taxlots_table/taxlot_chip.dart';
import 'package:finance_app/components/taxlots_table/taxlot_columns.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:finance_app/components/taxlots_table/taxlot_row_cells.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term_colors.dart';
import 'package:finance_app/components/taxlots_table/taxlot_type.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';
import 'package:flutter/material.dart';

/// One lot, drawn as the design draws a row.
///
/// Every string on it is a value the backend produced. The only decisions
/// this widget makes are which colour a term takes and which colour a
/// gain/loss takes, and both come from a declared enum rather than from the
/// look of a figure.
class TaxLotRowTile extends StatelessWidget {
  /// Creates a row.
  const TaxLotRowTile({required this.lot, super.key});

  /// The lot to draw.
  final TaxLot lot;

  @override
  Widget build(BuildContext context) {
    final palette = TaxLotPalette.of(context);
    final term = lot.term.colorsIn(palette);
    return Semantics(
      container: true,
      label:
          '${lot.acquiredOn} ${lot.costBasisDisplay} '
          '${lot.proceedsDisplay} ${lot.gainLossDisplay} ${lot.termLabel}',
      child: ExcludeSemantics(
        child: Container(
          height: TaxLotMetrics.rowHeight,
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.border),
            borderRadius: TaxLotMetrics.rowBorderRadius,
          ),
          child: ClipRRect(
            // Inside the 1 px hairline, so the rail's outer corners follow
            // the row's rounding instead of squaring it off.
            borderRadius: TaxLotMetrics.rowInnerBorderRadius,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: TaxLotMetrics.rowAccentWidth,
                  child: ColoredBox(color: term.accent),
                ),
                Expanded(
                  child: Padding(
                    padding: TaxLotMetrics.rowPadding,
                    child: _cells(palette, term),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cells(TaxLotPalette palette, TaxLotTermColors term) {
    return TaxLotColumns(
      leading: const TaxLotCheckBox(),
      cells: <Widget>[
        TaxLotCell(lot.acquiredOn, style: TaxLotType.date(palette.primaryText)),
        TaxLotCell(
          lot.costBasisDisplay,
          style: TaxLotType.figure(palette.figureText),
          align: TextAlign.right,
        ),
        TaxLotCell(
          lot.proceedsDisplay,
          style: TaxLotType.figure(palette.primaryText),
          align: TextAlign.right,
        ),
        TaxLotCell(
          lot.gainLossDisplay,
          // The only colour decision in the row, and it comes from the
          // backend's `trend` enum rather than from the sign printed in
          // the string beside it.
          style: TaxLotType.figureEmphasis(switch (lot.trend) {
            TaxLotTrend.up => palette.gain,
            TaxLotTrend.down => palette.loss,
          }),
          align: TextAlign.right,
        ),
        TaxLotChip(
          label: lot.termLabel,
          background: term.chipBackground,
          padding: TaxLotMetrics.rowChipPadding,
          style: TaxLotType.rowChip(term.chipForeground),
        ),
      ],
    );
  }
}
