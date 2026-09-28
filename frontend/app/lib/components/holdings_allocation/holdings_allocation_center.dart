import 'package:finance_app/charts/allocation_palette.dart';
import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/components/holdings_allocation/holdings_summary_tokens.dart';
import 'package:flutter/material.dart';

/// The total in the ring's hole, as the design draws the catalog card
/// (GGU-145): `$482,915.20` over `Total market value`.
///
/// The caption is `total.label` and **not** design's shorter *"total value"*:
/// the label is the server's word and follows the `locale` option, so writing
/// design's copy here would be the client authoring a string it does not own
/// (N-1).
class HoldingsAllocationTotalCenter extends StatelessWidget {
  /// Creates the label.
  const HoldingsAllocationTotalCenter({
    required this.display,
    required this.label,
    super.key,
  });

  /// `total.amount.display`.
  final String display;

  /// `total.label`.
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = HoldingsSummaryText.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          display,
          textAlign: TextAlign.center,
          style: HoldingsSummaryText.total(text.primary),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: HoldingsSummaryText.totalLabel(text.secondary),
        ),
      ],
    );
  }
}

/// The count in the ring's hole: the unit over the count (`Holdings` / `7`),
/// both copied from `center.*` — the client counts nothing (N-2).
///
/// This is what a card **under someone else's header** shows, because there
/// the total is already on screen one widget up. The catalog card draws
/// [HoldingsAllocationTotalCenter] instead and announces the count to a
/// screen reader, so no server field goes unread in either variant.
class HoldingsAllocationCenter extends StatelessWidget {
  /// Creates the label.
  const HoldingsAllocationCenter({
    required this.count,
    required this.unit,
    super.key,
  });

  /// `center.count`; an empty string draws nothing.
  final String count;

  /// `center.unit`.
  final String unit;

  @override
  Widget build(BuildContext context) {
    if (count.isEmpty) return const SizedBox.shrink();
    final chart = ChartPalette.of(context);
    final muted = AllocationPalette.of(context).legendWeight;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(unit, style: ChartText.axis(muted)),
        Text(count, style: ChartText.legendFigure(chart.title, size: 18)),
      ],
    );
  }
}
