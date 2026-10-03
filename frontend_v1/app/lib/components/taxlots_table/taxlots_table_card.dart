import 'package:finance_app/components/taxlots_table/taxlot_column_headers.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_mobile_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_mobile_tile.dart';
import 'package:finance_app/components/taxlots_table/taxlot_row_tile.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_data.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_empty.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_footer.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_header.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_surface.dart';
import 'package:flutter/material.dart';

/// Renders `taxlots.table.v1` as the UI Kit's tax-lot card.
///
/// The catalog names this view's A2UI component `TaxLotTable`. Layout is the
/// kit's, measured into [TaxLotMetrics] and `TaxLotMobileMetrics`; colour is
/// the kit's, measured into `TaxLotTokens`. One tree serves light and dark,
/// because the artboards differ only in palette.
///
/// **Two forms, one model.** Above [TaxLotMetrics.stackBelow] the lots are a
/// table; below it they are the kit's stacked blocks. Both bind the same
/// [TaxLotsTableData] and show the same six values — the breakpoint changes
/// the arrangement, never the content (spec `frontend/0027` OD-7).
///
/// **Rows render in arrival order.** Which lots a sale consumes, and in what
/// order, is the `lot_method` option's answer — sorting them here would
/// silently answer a different question (N-10).
class TaxLotsTableCard extends StatelessWidget {
  /// Creates the card.
  const TaxLotsTableCard({required this.data, super.key});

  /// Everything the card draws.
  final TaxLotsTableData data;

  @override
  Widget build(BuildContext context) => TaxLotsTableSurface(
    child: LayoutBuilder(
      builder: (context, constraints) =>
          _body(stacked: constraints.maxWidth < TaxLotMetrics.stackBelow),
    ),
  );

  /// The card at one of its two widths — the breakpoint is read once, so the
  /// header and the lots cannot disagree about which form this is.
  Widget _body({required bool stacked}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      TaxLotsTableHeader(data: data, stacked: stacked),
      const SizedBox(height: TaxLotMetrics.headerGap),
      if (data.lots.isEmpty)
        const TaxLotsTableEmpty()
      else if (stacked)
        ..._stacked()
      else
        ..._table(),
      const SizedBox(height: TaxLotMetrics.dividerGap),
      TaxLotsTableFooter(
        label: data.realizedLabel,
        totalDisplay: data.realizedDisplay,
        trend: data.realizedTrend,
        splits: data.splits,
      ),
    ],
  );

  /// The desktop form: a caption line over the rows, on one grid.
  List<Widget> _table() => <Widget>[
    TaxLotColumnHeaders(
      unitsLabel: data.unitsLabel,
      costBasisLabel: data.costBasisLabel,
      proceedsLabel: data.proceedsLabel,
    ),
    for (final (index, lot) in data.lots.indexed) ...<Widget>[
      if (index > 0) const SizedBox(height: TaxLotMetrics.rowGap),
      TaxLotRowTile(lot: lot),
    ],
  ];

  /// The phone form: one block per lot, each carrying its own captions —
  /// which is why there is no caption line above them.
  List<Widget> _stacked() => <Widget>[
    for (final (index, lot) in data.lots.indexed) ...<Widget>[
      if (index > 0) const SizedBox(height: TaxLotMobileMetrics.tileGap),
      TaxLotMobileTile(
        lot: lot,
        unitsLabel: data.unitsLabel,
        costBasisLabel: data.costBasisLabel,
        proceedsLabel: data.proceedsLabel,
      ),
    ],
  ];
}
