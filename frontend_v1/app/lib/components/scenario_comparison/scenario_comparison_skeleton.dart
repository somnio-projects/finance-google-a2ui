import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_layout.dart';
import 'package:finance_app/skeleton/skeleton_shimmer.dart';
import 'package:flutter/material.dart';

/// The `ScenarioComparison` card while its scenarios are computed: the
/// catalog page's `Loading · skeleton columns` — a header row of three
/// shimmering column heads and four metric rows, each a label bar and three
/// value bars, in the table's own column grid.
class ScenarioComparisonSkeleton extends StatelessWidget {
  /// Creates the skeleton.
  const ScenarioComparisonSkeleton({super.key});

  /// The metric label column, wide enough for the longest label bar.
  static const double labelColumnWidth = 84;

  /// The header row's label bar, from `width:46px`.
  static const double headerLabelWidth = 46;

  /// The four metric rows' label bars, from the artboard, top to bottom.
  static const List<double> rowLabelWidths = <double>[70, 84, 58, 78];

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(
          ScenarioComparisonLayout.cardRadius,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const _SkeletonRow(
              labelWidth: headerLabelWidth,
              labelHeight: 14,
              cellHeight: 34,
            ),
            const SizedBox(height: 10),
            for (final width in rowLabelWidths)
              Padding(
                padding: EdgeInsets.only(
                  top: width == rowLabelWidths.first ? 0 : 10,
                ),
                child: _SkeletonRow(
                  labelWidth: width,
                  labelHeight: 11,
                  cellHeight: 15,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({
    required this.labelWidth,
    required this.labelHeight,
    required this.cellHeight,
  });

  final double labelWidth;
  final double labelHeight;
  final double cellHeight;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      SizedBox(
        width: ScenarioComparisonSkeleton.labelColumnWidth,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SkeletonShimmer(width: labelWidth, height: labelHeight),
        ),
      ),
      for (var column = 0; column < 3; column++) ...<Widget>[
        const SizedBox(width: ScenarioComparisonLayout.columnGap),
        Expanded(child: SkeletonShimmer(height: cellHeight)),
      ],
    ],
  );
}
