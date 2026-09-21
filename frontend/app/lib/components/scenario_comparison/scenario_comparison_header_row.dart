import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_header_border.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_layout.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_model.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_tokens.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_track_row.dart';
import 'package:flutter/material.dart';

/// The table's head: a `Metric` caption, then one tab per scenario.
///
/// **No column is marked.** The design badges one header `★ Recommended`
/// and tints it, driven by `scenarios[].recommended`. The contract has no
/// such field and spec `backend/0017` OD-4 says it never will: choosing a
/// lot-selection method for someone is tax advice, and which column is
/// preferable depends on a marginal rate, carried-forward losses and a
/// jurisdiction the backend does not know. `specs/frontend/0003` OD-3
/// records the divergence and its reasoning in full.
class ScenarioComparisonHeaderRow extends StatelessWidget {
  /// Creates the header row.
  const ScenarioComparisonHeaderRow({required this.columns, super.key});

  /// The caption above the metric names. Client copy — the contract carries
  /// no label for this cell, and the design writes `Metric`.
  static const String metricHeading = 'Metric';

  /// The scenarios, in arrival order (N-10).
  final List<ScenarioColumn> columns;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final tokens = ScenarioComparisonTokens.of(context);
    // The tabs carry a border, so they must all be as tall as the tallest:
    // `IntrinsicHeight` is the Flutter spelling of `align-items: stretch`.
    return IntrinsicHeight(
      child: ScenarioTrackRow(
        columnCount: columns.length,
        leading: Padding(
          padding: ScenarioComparisonLayout.metricHeaderPadding,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              metricHeading,
              style: ScenarioComparisonText.caption(tokens.caption),
            ),
          ),
        ),
        cells: <Widget>[
          for (final column in columns)
            _ColumnHeader(column: column, palette: palette, tokens: tokens),
        ],
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.column,
    required this.palette,
    required this.tokens,
  });

  final ScenarioColumn column;
  final ChartPalette palette;
  final ScenarioComparisonTokens tokens;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: ScenarioHeaderBorderPainter(
      color: tokens.headerBorder,
      radius: ScenarioComparisonLayout.headerCellRadius,
    ),
    child: Padding(
      // The three edges that carry a line; the bottom is open.
      padding:
          ScenarioComparisonLayout.headerCellPadding +
          const EdgeInsets.only(
            top: ScenarioComparisonLayout.hairline,
            left: ScenarioComparisonLayout.hairline,
            right: ScenarioComparisonLayout.hairline,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // The design's two lines, taken from the contract's two fields.
          // `label` is never split on its dash to recover a description:
          // reading structure out of a server string is N-5.
          Text(
            column.method,
            style: ScenarioComparisonText.columnTitle(palette.title),
          ),
          Text(
            column.label,
            style: ScenarioComparisonText.columnLabel(tokens.caption),
          ),
        ],
      ),
    ),
  );
}
