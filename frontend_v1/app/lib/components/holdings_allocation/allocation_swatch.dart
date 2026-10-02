import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_legend.dart';
import 'package:flutter/material.dart';

/// The colour chip that opens a legend row, and grows when its slice is the
/// selected one.
///
/// Its own file because the row it belongs to is at the 150-line budget.

class AllocationSwatch extends StatelessWidget {
  /// Creates the chip.
  const AllocationSwatch({
    required this.color,
    required this.selected,
    super.key,
  });

  /// The slice's colour — the same one the ring uses.
  final Color color;

  /// Whether its slice is selected.
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: HoldingsAllocationLegend.swatchSize,
    height: HoldingsAllocationLegend.swatchSize,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(
        HoldingsAllocationLegend.swatchRadius,
      ),
      // Selection is a ring around the swatch, which leaves the category's
      // own colour saying what it says (the waterfall's rule for a bar).
      border: selected
          ? Border.all(color: ChartPalette.of(context).title, width: 1.5)
          : null,
    ),
  );
}
