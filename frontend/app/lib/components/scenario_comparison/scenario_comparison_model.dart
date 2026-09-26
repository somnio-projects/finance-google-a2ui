import 'package:finance_app/components/scenario_comparison/scenario_comparison_rows.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_summary.dart';
import 'package:flutter/foundation.dart';

export 'scenario_comparison_summary.dart';

/// The sale every column of the card is costed against.
///
/// `scenario.comparison.v1` keeps these five values **once**, outside the
/// columns, because the units, the price and the proceeds are identical
/// under every lot-selection method (spec `backend/0017` §3). A reader
/// scanning the columns is therefore scanning differences.
///
/// Every field is a `String` the backend already formatted. There is no
/// `double` here to be tempted into arithmetic with — prohibition N-2 made
/// structural rather than remembered, the shape `HoldingsAllocationRow` uses.
@immutable
class ScenarioSubject {
  /// Creates a subject.
  const ScenarioSubject({
    required this.label,
    required this.symbol,
    required this.quantityDisplay,
    required this.priceDisplay,
    required this.proceedsDisplay,
  });

  /// The payload's `subject.label`, e.g. `Bitcoin`.
  final String label;

  /// The payload's `subject.symbol`, e.g. `BTC`.
  final String symbol;

  /// The payload's `subject.quantity_display`, e.g. `0.18`.
  final String quantityDisplay;

  /// The payload's `subject.price.display`, e.g. `$64,250.00`.
  ///
  /// Quoted at price precision by the backend so a sub-cent asset ties out
  /// against the quantity beside it (spec `backend/0013` OD-4).
  final String priceDisplay;

  /// The payload's `subject.proceeds.display`, e.g. `$11,565.00`.
  final String proceedsDisplay;
}

/// One scenario: the lot-selection method a column is costed under.
///
/// Both fields are rendered verbatim and neither is parsed. In particular
/// [label] is **not** split on its dash to recover a description — reading
/// structure out of a server-written string is prohibition N-5, and the
/// backend already sends the token separately as [method].
@immutable
class ScenarioColumn {
  /// Creates a column.
  const ScenarioColumn({
    required this.key,
    required this.method,
    required this.kind,
    required this.label,
    required this.caption,
    required this.recommended,
    required this.recommendationLabel,
  });

  /// The payload's `columns[].key` — what a row's `winner` names.
  ///
  /// Not `method`: the timing column shares a method with a lot-ordering one,
  /// so a method is no longer unique across columns.
  final String key;

  /// The payload's `columns[].method`: `FIFO`, `LIFO` or `HIFO`.
  ///
  /// A token, not a figure. It is what `spread.highest` and `spread.lowest`
  /// name, which is the only reason the card keeps it beside [label].
  final String method;

  /// The payload's `columns[].label`, e.g. `FIFO — oldest lots first`.
  final String label;

  /// The payload's `columns[].kind`: `lot_method` or `timing`.
  ///
  /// Waiting is not an ordering of lots, so it is not a fourth method
  /// (backend spec 0051 OD-2).
  final String kind;

  /// The payload's `columns[].caption`, e.g. `tax-optimized`.
  final String caption;

  /// The payload's `columns[].recommended` — a declared flag, read with
  /// `ViewPayload.flag` and never worked out here.
  final bool recommended;

  /// The tag drawn on the recommended column, or null on the rest.
  final String? recommendationLabel;
}

/// Everything `scenario.comparison.v1` renders.
///
/// The payload arrives column-major — one object per scenario, each carrying
/// the same four figures — and the design draws it row-major, one row per
/// metric. [metrics] is that transposition, done once in the component's
/// `read` so the widgets stay a straight binding. Transposing is layout: it
/// reorders nothing within a row, so the columns keep the order the backend
/// sent them (N-10).
@immutable
class ScenarioComparisonData {
  /// Creates the model.
  const ScenarioComparisonData({
    required this.title,
    required this.subject,
    required this.columns,
    required this.metrics,
    required this.summary,
    required this.spread,
    required this.notes,
  });

  /// The payload's `title`, e.g. `Same sale, different lot method`.
  final String title;

  /// The sale being costed, rendered once above the table.
  final ScenarioSubject subject;

  /// The scenarios, in the order the caller asked for them (N-10).
  final List<ScenarioColumn> columns;

  /// One row per figure a column carries, each holding one display string
  /// per entry of [columns], in the same order.
  final List<ScenarioMetricRow> metrics;

  /// The header pill and the footer sentence.
  final ScenarioSummary summary;

  /// The difference between the extremes, and which methods sit at each end.
  final ScenarioSpread spread;

  /// The payload's `notes`, rendered verbatim and never dropped (N-9).
  ///
  /// One states the tax rates the card costed with and one says the
  /// recommendation is arithmetic under them rather than advice. Both are
  /// what make the card's ranking checkable instead of asserted — dropping
  /// either would leave a tax claim with its disclaimer somewhere else
  /// (backend spec 0051 OD-4).
  final List<ScenarioNote> notes;
}
