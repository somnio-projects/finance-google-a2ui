import 'package:flutter/foundation.dart';

/// One row of the comparison table: a figure, once per scenario.
///
/// [label] is **client copy**, not payload text, and that is a gap rather
/// than a shortcut. The design drives its rows from a server-sent
/// `metrics[].label`; `scenario.comparison.v1` has no such list — it carries
/// four fixed, named members per column instead. So the four row names are
/// written here, beside the four paths they title, and
/// `specs/frontend/0003` OD-1 records the divergence.
@immutable
class ScenarioMetricRow {
  /// Creates a metric row.
  const ScenarioMetricRow({required this.label, required this.valueDisplays});

  /// The row's name, e.g. `Cost basis`. Client copy — see the class doc.
  final String label;

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

  /// Whether the scenarios produced different results.
  ///
  /// Read from the **presence of the two ends**, not from the payload's
  /// `spread.differs`, because `ViewPayload` exposes no boolean accessor and
  /// adding one would edit a shared file (`specs/frontend/0003` OD-2). The
  /// contract ties the two together: spec `backend/0017` AC-6 says that when
  /// nothing differs the card "names neither" end, and
  /// `scenario_comparison_component_test.dart` asserts the published example
  /// still agrees with `differs`.
  bool get differs => highest != null && lowest != null;
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
