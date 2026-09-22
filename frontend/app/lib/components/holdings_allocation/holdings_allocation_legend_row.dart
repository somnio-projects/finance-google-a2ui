import 'package:finance_app/charts/allocation_palette.dart';
import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/components/holdings_allocation/allocation_swatch.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_legend.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:flutter/material.dart';

/// One legend row: swatch, label and weight on the left; value and the day
/// change stacked on the right, as the design lays them out (spec 0026 §2).
class AllocationLegendRow extends StatelessWidget {
  /// Creates the row.
  const AllocationLegendRow({
    required this.category,
    required this.index,
    required this.selected,
    required this.onTap,
    required this.color,
    super.key,
  });

  /// The slice.
  final AllocationCategory category;

  /// Its position, reported on tap.
  final int index;

  /// Whether it is the selected slice.
  final bool selected;

  /// Called with [index] on tap; null disables tapping.
  final void Function(int index)? onTap;

  /// The slice's colour — the same one the ring uses.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final chart = ChartPalette.of(context);
    final palette = AllocationPalette.of(context);
    final change = category.changeDisplay;
    final tone = switch (category.trend) {
      'up' => chart.barGain,
      'down' => chart.barLoss,
      _ => palette.legendWeight,
    };
    final glyph = switch (category.trend) {
      'up' => '▲',
      'down' => '▼',
      _ => '—',
    };
    return Semantics(
      container: true,
      selected: selected,
      label:
          '${category.label} ${category.valueDisplay} '
          '${category.weightDisplay}'
          '${change.isEmpty ? '' : ' $change'}',
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
                  AllocationSwatch(color: color, selected: selected),
                  const SizedBox(width: HoldingsAllocationLegend.columnGap),
                  Expanded(
                    child: Text(
                      category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ChartText.legendLabel(chart.title),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category.weightDisplay,
                    style: ChartText.legendFigure(
                      palette.legendWeight,
                      size: 11,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Both columns give way, so a narrow legend trims a
                  // figure rather than overflowing the row — and the `Align`
                  // is what puts the figures against that right edge.
                  // `Expanded` and `Flexible` both default to `flex: 1`, so
                  // the free space was split 50/50 and this loose column sat
                  // at the START of its half; `crossAxisAlignment: end`
                  // cannot fix that, because the Column is already as wide
                  // as its widest child (spec frontend/0021 OD-1).
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            category.valueDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ChartText.legendFigure(
                              palette.legendValue,
                              size: 12.5,
                            ),
                          ),
                          if (change.isNotEmpty)
                            Text(
                              '$glyph $change',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ChartText.legendFigure(tone, size: 11),
                            ),
                        ],
                      ),
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
