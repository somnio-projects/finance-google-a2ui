import 'package:finance_app/charts/allocation_palette.dart';
import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:flutter/material.dart';

/// The words in the ring's hole: the unit over the count (`Classes` / `4`),
/// both copied from `center.*` — the client counts nothing (N-6).
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
