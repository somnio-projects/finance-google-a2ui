import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_header_row.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_layout.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_model.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_rows.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_tokens.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_track_row.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_value_cell.dart';
import 'package:flutter/material.dart';

/// The comparison grid: one header per scenario, one row per metric.
///
/// The payload is column-major and the design is row-major; the
/// transposition happened in the component's `read`, so this widget only
/// places what it is given. Columns keep their arrival order (N-10).
///
/// **No cell is emphasised.** The design tints the better cell of each row
/// green and marks it with a tick, driven by `metrics[].betterWhen`. The
/// contract ships no such field — see [ScenarioComparisonHeaderRow] and
/// `specs/frontend/0004` OD-3 for why it never will.
class ScenarioComparisonTable extends StatelessWidget {
  /// Creates the table.
  const ScenarioComparisonTable({
    required this.columns,
    required this.metrics,
    super.key,
  });

  /// The scenarios, in arrival order.
  final List<ScenarioColumn> columns;

  /// One row per figure, each holding one display string per [columns] entry.
  final List<ScenarioMetricRow> metrics;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final tokens = ScenarioComparisonTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ScenarioComparisonHeaderRow(columns: columns),
        for (final metric in metrics)
          _MetricRow(
            metric: metric,
            columns: columns,
            palette: palette,
            tokens: tokens,
          ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.metric,
    required this.columns,
    required this.palette,
    required this.tokens,
  });

  final ScenarioMetricRow metric;
  final List<ScenarioColumn> columns;
  final ChartPalette palette;
  final ScenarioComparisonTokens tokens;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: tokens.rowRule)),
    ),
    child: Padding(
      // Plus the rule above it, which Flutter paints over the child.
      padding:
          ScenarioComparisonLayout.rowPadding +
          const EdgeInsets.only(top: ScenarioComparisonLayout.hairline),
      child: ScenarioTrackRow(
        columnCount: columns.length,
        leading: Padding(
          padding: ScenarioComparisonLayout.metricCellPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                metric.label,
                style: ScenarioComparisonText.metricLabel(tokens.metricLabel),
              ),
              // Which way this row wins, in the backend's words. A Dart
              // constant here would not follow the `locale` option (N-9).
              Text(
                metric.directionLabel,
                style: ScenarioComparisonText.metricLabel(tokens.metricLabel),
              ),
            ],
          ),
        ),
        cells: <Widget>[
          for (final (index, display) in metric.valueDisplays.indexed)
            ScenarioValueCell(
              display: display,
              // Read, never decided: the backend named the winning column
              // and this compares two **keys**, never two figures (N-2).
              isWinner:
                  metric.winner != null &&
                  index < columns.length &&
                  columns[index].key == metric.winner,
              palette: palette,
              tokens: tokens,
            ),
        ],
      ),
    ),
  );
}
