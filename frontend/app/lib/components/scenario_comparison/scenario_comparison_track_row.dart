import 'package:finance_app/components/scenario_comparison/scenario_comparison_layout.dart';
import 'package:flutter/material.dart';

/// One row of the comparison grid: a wide leading track, then one track per
/// scenario, separated by the design's 8 px gap.
///
/// This is the Flutter spelling of the design's
/// `grid-template-columns: 1.35fr 1fr 1fr`. It is its own widget, and public,
/// because three rows line up against the same tracks — the header, each
/// metric row — and two places computing the same flex is how two rows stop
/// agreeing.
class ScenarioTrackRow extends StatelessWidget {
  /// Creates a row of tracks.
  const ScenarioTrackRow({
    required this.columnCount,
    required this.leading,
    required this.cells,
    super.key,
  });

  /// How many scenario tracks the grid has, which sets the leading track's
  /// share: `1.35fr` at two scenarios, `1.2fr` at three
  /// ([ScenarioComparisonLayout.metricFlex]).
  ///
  /// Passed rather than derived from `cells.length` so the header row and
  /// the metric rows provably agree even while one of them is empty.
  final int columnCount;

  /// The leading track's content: a metric's name, or the `Metric` caption.
  final Widget leading;

  /// One widget per scenario track, in arrival order (N-10).
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        flex: ScenarioComparisonLayout.metricFlex(columnCount),
        child: leading,
      ),
      for (final cell in cells) ...<Widget>[
        const SizedBox(width: ScenarioComparisonLayout.columnGap),
        Expanded(flex: ScenarioComparisonLayout.scenarioFlex, child: cell),
      ],
    ],
  );
}
