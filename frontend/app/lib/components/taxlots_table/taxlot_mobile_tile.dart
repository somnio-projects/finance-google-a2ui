import 'package:finance_app/components/taxlots_table/taxlot_check_box.dart';
import 'package:finance_app/components/taxlots_table/taxlot_chip.dart';
import 'package:finance_app/components/taxlots_table/taxlot_column_headers.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_mobile_cell.dart';
import 'package:finance_app/components/taxlots_table/taxlot_mobile_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term_colors.dart';
import 'package:finance_app/components/taxlots_table/taxlot_type.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';
import 'package:flutter/material.dart';

/// One lot as the kit's phone artboard draws it: a stacked block.
///
/// The same six values as a table row, rearranged rather than trimmed — the
/// date and the term pill on the first line, the four figures under them with
/// a caption over each. A component that dropped a column on a phone would be
/// deciding which of the backend's figures matter, which is not its call.
class TaxLotMobileTile extends StatelessWidget {
  /// Creates a block.
  const TaxLotMobileTile({
    required this.lot,
    required this.costBasisLabel,
    required this.proceedsLabel,
    super.key,
  });

  /// The lot to draw.
  final TaxLot lot;

  /// The payload's `cost_basis.label`, the caption over that figure.
  final String costBasisLabel;

  /// The payload's `proceeds.label`, over the *Mkt value* figure (OD-1).
  final String proceedsLabel;

  @override
  Widget build(BuildContext context) {
    final palette = TaxLotPalette.of(context);
    final term = lot.term.colorsIn(palette);
    return Semantics(
      container: true,
      label: TaxLotCheckBox.rowLabel(lot),
      child: ExcludeSemantics(
        child: Container(
          height: TaxLotMobileMetrics.tileHeight,
          color: lot.fullySold ? palette.selectedRow : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: TaxLotMetrics.railWidth,
                child: ColoredBox(color: term.accent),
              ),
              const SizedBox(width: TaxLotMobileMetrics.railGap),
              Expanded(
                child: Padding(
                  padding: TaxLotMobileMetrics.tilePadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _firstLine(palette, term),
                      const SizedBox(height: TaxLotMobileMetrics.lineGap),
                      Expanded(child: _grid(palette)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _firstLine(TaxLotPalette palette, TaxLotTermColors term) => Row(
    children: <Widget>[
      TaxLotCheckBox(ticked: lot.fullySold),
      const SizedBox(width: TaxLotMobileMetrics.railGap),
      Expanded(
        child: Text(
          lot.acquiredOnDisplay,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TaxLotType.mobileDate(palette.primaryText),
        ),
      ),
      TaxLotChip(
        label: lot.termLabel,
        background: term.chipBackground,
        padding: TaxLotMetrics.chipPadding,
        style: TaxLotType.chip(term.chipForeground),
      ),
    ],
  );

  Widget _grid(TaxLotPalette palette) {
    final cells = <(String, String, bool)>[
      (TaxLotColumnHeaders.shares, lot.unitsDisplay, false),
      (costBasisLabel, lot.costBasisDisplay, false),
      (proceedsLabel, lot.proceedsDisplay, false),
      (TaxLotColumnHeaders.gainLoss, lot.gainLossDisplay, true),
    ];
    return Row(
      children: <Widget>[
        for (final (index, (caption, value, accent)) in cells.indexed) ...[
          if (index > 0) const SizedBox(width: TaxLotMobileMetrics.cellGap),
          Expanded(
            flex: TaxLotMobileMetrics.cellFlex[index],
            child: TaxLotMobileCell(
              caption: caption,
              value: value,
              palette: palette,
              trend: accent ? lot.trend : null,
            ),
          ),
        ],
      ],
    );
  }
}
