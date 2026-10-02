import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_header_border.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_layout.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_model.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_recommended_tag.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_text.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_tokens.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_track_row.dart';
import 'package:flutter/material.dart';

/// The table's head: a `Metric` caption, then one tab per scenario.
///
/// **One column may be marked, and the backend decides which.** This used to
/// say no column ever would: spec `backend/0017` OD-4 declined to recommend a
/// lot-selection method, because preferring one is tax advice that depends on
/// a marginal rate, carried-forward losses and a jurisdiction the backend does
/// not know. GGU-136 did not overturn that — it narrowed the claim until the
/// backend could defend it. `recommended` now means *"this column wins the
/// `net_after_tax` row at the rates printed on the card"*, which is
/// arithmetic, and `recommendation_label` carries the word to draw. The
/// header renders the tag when both arrive and nothing when they do not; it
/// never derives the mark itself.
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
              style: ScenarioComparisonText.metricHeading(tokens.caption),
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
      // The recommended column is **filled**, not only outlined, and the
      // fill is lavender rather than green: the design spends green on a
      // gain and the accent lavender on the thing to look at. Drawing this
      // green was the component's largest visual error.
      color: column.recommended
          ? tokens.verdict.recommendedBorder
          : tokens.headerBorder,
      radius: ScenarioComparisonLayout.headerCellRadius,
      fill: column.recommended ? tokens.verdict.recommendedSurface : null,
    ),
    child: Semantics(
      // **`columns[].label` is announced here, and this is the whole of
      // where it survives.** The design's header is two lines, `FIFO` over
      // `default order`, which are `method` and `caption`; the long form
      // `FIFO — oldest lots first` has no slot in the frame. Dropping a
      // server-written label outright would be N-9, so it is spoken rather
      // than drawn — and that is a decision recorded in
      // `specs/frontend/0031`, not a silent omission. If it needs to be
      // visible again, the frame is what has to change.
      label: _announcement,
      excludeSemantics: true,
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
            // **Two lines, not three.** The redesign's header is the method
            // and its caption; `columns[].label` — `FIFO — oldest lots first`
            // — has no slot in it. It is still served and still rendered: the
            // footer sentence names the winning column by it, which is where a
            // reader meets the long form now.
            Text(
              column.caption,
              style: ScenarioComparisonText.columnLabel(tokens.caption),
            ),
            // Drawn only when the backend tagged this column, and with the
            // backend's own word — never one composed here, and never
            // uppercased: the design's `text-transform` is CSS, and applying
            // it to a server string would be the client reformatting a value
            // the backend wrote (N-1, N-9).
            if (column.recommendationLabel case final tag?)
              ScenarioRecommendedTag(label: tag, tokens: tokens),
          ],
        ),
      ),
    ),
  );

  /// Everything this header says, in reading order, for a screen reader.
  String get _announcement => <String>[
    column.method,
    column.caption,
    column.label,
    ?column.recommendationLabel,
  ].join('. ');
}
