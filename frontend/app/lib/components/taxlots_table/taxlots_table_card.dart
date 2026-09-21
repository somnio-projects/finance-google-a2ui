import 'package:finance_app/components/taxlots_table/taxlot_chip.dart';
import 'package:finance_app/components/taxlots_table/taxlot_column_headers.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:finance_app/components/taxlots_table/taxlot_row_tile.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlot_type.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_empty.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_footer.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';
import 'package:flutter/material.dart';

/// Renders `taxlots.table.v1` as the design's tax-lot card.
///
/// The catalog names this view's A2UI component `TaxLotTable`. Layout is
/// the artboard's, measured into [TaxLotMetrics]; colour is the artboard's,
/// measured into `TaxLotTokens`. One tree serves light and dark, because
/// the two artboards differ only in palette.
///
/// **Rows render in arrival order.** Which lots a sale consumes, and in
/// what order, is the `lot_method` option's answer — sorting them here
/// would silently answer a different question (N-10).
class TaxLotsTableCard extends StatelessWidget {
  /// Creates the card.
  const TaxLotsTableCard({required this.data, super.key});

  /// Everything the card draws.
  final TaxLotsTableData data;

  @override
  Widget build(BuildContext context) {
    final palette = TaxLotPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: TaxLotMetrics.cardBorderRadius,
      ),
      child: Padding(
        padding: TaxLotMetrics.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Header(data: data, palette: palette),
            const SizedBox(height: TaxLotMetrics.headerGap),
            if (data.lots.isEmpty)
              const TaxLotsTableEmpty()
            else ...<Widget>[
              TaxLotColumnHeaders(
                costBasisLabel: data.costBasisLabel,
                proceedsLabel: data.proceedsLabel,
              ),
              for (final (index, lot) in data.lots.indexed) ...<Widget>[
                if (index > 0) const SizedBox(height: TaxLotMetrics.rowGap),
                TaxLotRowTile(lot: lot),
              ],
            ],
            const SizedBox(height: TaxLotMetrics.headerGap),
            TaxLotsTableFooter(
              label: data.realizedLabel,
              totalDisplay: data.realizedDisplay,
              splits: data.splits,
            ),
          ],
        ),
      ),
    );
  }
}

/// The card's caption and the term key beside it.
///
/// The design's artboard puts gallery chrome here (`DEFAULT · NVDA · 4
/// LOTS`); the payload carries a `title` and a `subtitle`, and both are
/// shown rather than dropped.
class _Header extends StatelessWidget {
  const _Header({required this.data, required this.palette});

  final TaxLotsTableData data;
  final TaxLotPalette palette;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(data.title, style: TaxLotType.title(palette.primaryText)),
            Text(data.subtitle, style: TaxLotType.subtitle(palette.labelText)),
          ],
        ),
      ),
      for (final (index, split) in data.splits.indexed) ...<Widget>[
        if (index > 0) const SizedBox(width: TaxLotMetrics.chipGap),
        _legendChip(split),
      ],
    ],
  );

  /// One key pill, from a `by_term` half's own label.
  Widget _legendChip(TaxLotTermSplit split) {
    final term = split.term.colorsIn(palette);
    return TaxLotChip(
      label: split.label,
      background: term.chipBackground,
      border: term.chipBorder,
      padding: TaxLotMetrics.legendChipPadding,
      style: TaxLotType.legendChip(term.chipForeground),
    );
  }
}
