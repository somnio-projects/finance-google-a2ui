import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_header_row.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_layout.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_model.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_rows.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_tokens.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_track_row.dart';
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
/// `specs/frontend/0003` OD-3 for why it never will.
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
            columnCount: columns.length,
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
    required this.columnCount,
    required this.palette,
    required this.tokens,
  });

  final ScenarioMetricRow metric;
  final int columnCount;
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
        columnCount: columnCount,
        leading: Padding(
          padding: ScenarioComparisonLayout.metricCellPadding,
          child: Text(
            metric.label,
            style: ScenarioComparisonText.metricLabel(tokens.metricLabel),
          ),
        ),
        cells: <Widget>[
          for (final display in metric.valueDisplays)
            Padding(
              padding: ScenarioComparisonLayout.valueCellPadding,
              child: Text(
                display,
                textAlign: TextAlign.end,
                style: ScenarioComparisonText.value(palette.title),
              ),
            ),
        ],
      ),
    ),
  );
}
