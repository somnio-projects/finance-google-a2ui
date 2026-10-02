import 'package:flutter/foundation.dart';

/// One row of the comparison table: a figure, once per scenario.
///
/// **[label] used to be client copy, and that gap is now closed.** The design
/// drives its rows from a server-sent list; `scenario.comparison.v1` had no
/// such list, so the four row names were written in the component beside the
/// four paths they titled, and `specs/frontend/0004` OD-1 recorded the
/// divergence. Backend spec 0051 ships `rows[]`, so the label, the direction
/// hint and the winner all arrive as server strings and follow the `locale`
/// option — which a Dart constant never could (N-9).
@immutable
class ScenarioMetricRow {
  /// Creates a metric row.
  const ScenarioMetricRow({
    required this.label,
    required this.directionLabel,
    required this.winner,
    required this.valueDisplays,
  });

  /// The row's name, e.g. `Est. tax`. The payload's `rows[].label`.
  final String label;

  /// `higher is better` / `lower is better`, as the backend worded it.
  final String directionLabel;

  /// The `columns[].key` of the winning cell, or null when the row ties.
  ///
  /// **Read, never decided.** Marking the best cell means comparing two
  /// figures, and this card carries no raw member to compare — N-2 made
  /// structural rather than remembered.
  final String? winner;

  /// One `*.display` string per scenario, in column order (N-10).
  ///
  /// A `String` per cell and nothing else: there is no raw member here, so
  /// nothing in the widget layer can subtract one column from another. On a
  /// comparison card that is the temptation worth designing out — the
  /// difference between two scenarios is `spread`, which the backend
  /// computes (N-2).
  final List<String> valueDisplays;
}

/// The distance between the best and worst realised result, as the backend
/// measured it.
///
/// This is the card's one cross-column figure and the client computes no
/// part of it: [amountDisplay] arrives pre-formatted and [highest] and
/// [lowest] arrive as method tokens. Subtracting two columns here would be
/// prohibition N-2, and it is the single most tempting place in the app to
/// do it.
///
/// Naming the two ends is **not** a ranking. Spec `backend/0017` OD-4 is
/// explicit that a bigger realised gain is not reliably the better outcome —
/// it depends on a marginal rate, carried-forward losses and a jurisdiction
/// the backend does not know — so the card reports where the ends are and
/// says nothing about which one to pick.
@immutable
class ScenarioSpread {
  /// Creates a spread.
  const ScenarioSpread({
    required this.amountDisplay,
    required this.highest,
    required this.lowest,
  });

  /// The payload's `spread.amount.display`, e.g. `$2,520.00`.
  final String amountDisplay;

  /// The payload's `spread.highest`, or `null` when the methods coincide.
  final String? highest;

  /// The payload's `spread.lowest`, or `null` when the methods coincide.
  final String? lowest;

  /// Whether the backend named **either** end.
  ///
  /// This is the footer's one predicate, and the card has exactly one rule:
  /// each end that is present is shown, and the "methods coincide" line
  /// appears only when neither is. That rule is *total*, which is why it is
  /// spelled `||` and not `&&`.
  ///
  /// **The asymmetric case is reachable.** The contract declares
  /// `spread.highest` and `spread.lowest` as `default null`
  /// **independently**, and ties neither to `spread.differs`; a payload
  /// naming one end and not the other is therefore permitted, and a rule
  /// requiring both would have left it undefined on screen.
  ///
  /// It is read from the ends rather than from the payload's `differs`
  /// because `ViewPayload` exposes no boolean accessor. Adding
  /// `ViewPayload.flag(path)` is a **deferral, not a prohibition**
  /// (`specs/frontend/0004` OD-2): it is an additive accessor beside
  /// `optionalText`, the shape `geometry` already set, and it belongs in a
  /// PR that can weigh it for every caller.
  bool get namesAnyEnd => highest != null || lowest != null;
}

/// A compliance note the backend attached to the view.
///
/// Rendered verbatim and never dropped (N-9). One of the two says that no
/// method is recommended; that sentence is the backend's, not the client's,
/// and it is the reason the card can stay silent on the question without
/// leaving the reader to wonder.
@immutable
class ScenarioNote {
  /// Creates a note.
  const ScenarioNote({required this.label, required this.text});

  /// The payload's `notes[].label`, e.g. `Before tax`.
  final String label;

  /// The payload's `notes[].text`, already written for a reader.
  final String text;
}
