import 'package:finance_app/charts/allocation_palette.dart';
import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_legend.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:flutter/material.dart';

/// One legend row: swatch, label, weight, then the value.
///
/// Split from the legend itself only for the 150-line budget, and along
/// the seam that means something: the legend owns the list and this owns a
/// row's five columns. The metrics are the design's, measured from the
/// rendered page and held as constants on [HoldingsAllocationLegend].
class AllocationLegendRow extends StatelessWidget {
  /// Creates a row.
  const AllocationLegendRow({
    required this.category,
    required this.index,
    required this.selected,
    required this.onTap,
    super.key,
  });

  /// The category this row shows.
  final AllocationCategory category;

  /// Its position in the payload, which picks its swatch (N-10).
  final int index;

  /// Whether the reader has this category selected.
  final bool selected;

  /// Called with [index] when the row is tapped.
  final void Function(int index)? onTap;

  @override
  Widget build(BuildContext context) {
    final chart = ChartPalette.of(context);
    final palette = AllocationPalette.of(context);
    return Semantics(
      container: true,
      selected: selected,
      label:
          '${category.label} ${category.valueDisplay} '
          '${category.weightDisplay}',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap == null ? null : () => onTap!(index),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.legendDivider)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: HoldingsAllocationLegend.rowPadding,
              ),
              child: Row(
                children: <Widget>[
                  _Swatch(color: palette.swatchFor(index), selected: selected),
                  const SizedBox(width: HoldingsAllocationLegend.columnGap),
                  Flexible(
                    child: Text(
                      category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ChartText.legendLabel(chart.title),
                    ),
                  ),
                  const SizedBox(width: HoldingsAllocationLegend.columnGap),
                  Text(
                    category.weightDisplay,
                    style: ChartText.legendFigure(
                      palette.legendWeight,
                      size: 11,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    category.valueDisplay,
                    style: ChartText.legendFigure(
                      palette.legendValue,
                      size: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected});

  final Color color;
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
