import 'package:finance_app/components/taxlots_table/taxlot_chip.dart';
import 'package:finance_app/components/taxlots_table/taxlot_columns.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:finance_app/components/taxlots_table/taxlot_row_cells.dart';
import 'package:finance_app/components/taxlots_table/taxlot_sold_mark.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term_colors.dart';
import 'package:finance_app/components/taxlots_table/taxlot_type.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';
import 'package:flutter/material.dart';

/// One lot, drawn as the kit draws a table row.
///
/// The row has no hairline and no card of its own — that was the earlier
/// artboard. It is a 41 px band on the card's own surface, tinted only when
/// the sale consumes the lot whole, with the term rail flush left.
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
      label: TaxLotSoldMark.rowLabel(lot),
      child: ExcludeSemantics(
        child: Container(
          height: TaxLotMetrics.rowHeight,
          color: lot.fullySold ? palette.selectedRow : null,
          child: _cells(palette, term),
        ),
      ),
    );
  }

  Widget _cells(TaxLotPalette palette, TaxLotTermColors term) => TaxLotColumns(
    leading: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          width: TaxLotMetrics.railWidth,
          child: ColoredBox(color: term.accent),
        ),
        const SizedBox(width: TaxLotMetrics.railGap),
        TaxLotSoldMark(fullySold: lot.fullySold),
      ],
    ),
    cells: <Widget>[
      TaxLotCell(
        lot.acquiredOnDisplay,
        style: TaxLotType.cell(palette.primaryText),
        align: TaxLotMetrics.columnAlign[0],
      ),
      TaxLotCell(
        lot.unitsDisplay,
        style: TaxLotType.cell(palette.primaryText),
        align: TaxLotMetrics.columnAlign[1],
      ),
      TaxLotCell(
        lot.costBasisDisplay,
        style: TaxLotType.cell(palette.primaryText),
        align: TaxLotMetrics.columnAlign[2],
      ),
      TaxLotCell(
        lot.proceedsDisplay,
        style: TaxLotType.cellStrong(palette.primaryText),
        align: TaxLotMetrics.columnAlign[3],
      ),
      TaxLotCell(
        lot.gainLossDisplay,
        // The only colour decision in the row, and it comes from the
        // backend's `trend` enum rather than from the sign printed in the
        // string beside it.
        style: TaxLotType.cellAccent(lot.trend.colorFor(palette)),
        align: TaxLotMetrics.columnAlign[4],
      ),
      // The holding-period column: the pill and the duration on one line,
      // centred, as the artboard draws them. The duration is a server string
      // (`backend/0049`); until it existed the pill sat here alone and the
      // slot was kept empty beside it (spec `frontend/0027` OD-2).
      Align(
        // Scaled down rather than clipped. Both children are server strings
        // whose length this app does not get to choose — `termLabel` follows
        // the `locale` option, and a duration is `12 mo` or `5.5 yr` — so the
        // cell has to survive a pair wider than the artboard's. At the kit's
        // width nothing scales; the other five columns ellipsise instead,
        // which is right for a figure and wrong for a pill.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TaxLotChip(
                label: lot.termLabel,
                background: term.chipBackground,
                padding: TaxLotMetrics.chipPadding,
                style: TaxLotType.chip(term.chipForeground),
              ),
              const SizedBox(width: TaxLotMetrics.chipGap),
              // The row's own type scale in the muted colour, rather than a
              // size invented for one cell.
              Text(
                lot.holdingPeriodDisplay,
                maxLines: 1,
                style: TaxLotType.cell(palette.mutedText),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
