import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter/material.dart';

/// Which colour a waterfall step is drawn in.
///
/// Two maps, not one, because the design does not use one: a contribution's
/// bar and its figure share a mark, but **both totals are muted in text**
/// while the closing total's bar carries the accent. Deriving the label
/// colour from the bar colour got that one wrong, which is the kind of thing
/// a measurement catches and an eye does not.
///
/// Both are driven by the step's kind, which came from the backend's
/// `buckets[].direction` enum — never from the sign of a figure or of its
/// display string (`.claude/rules/frontend/contract-binding.md` §1).
extension WaterfallMarks on ChartPalette {
  /// The fill of the bar for a step of [kind].
  Color barFor(WaterfallStepKind kind) => switch (kind) {
    WaterfallStepKind.start => barNeutral,
    WaterfallStepKind.gain => barGain,
    WaterfallStepKind.loss => barLoss,
    WaterfallStepKind.total => barTotal,
  };

  /// The colour of the figure drawn for a step of [kind].
  ///
  /// The design draws both `$479,675` and `$482,915` in the muted grey; only
  /// a contribution's figure takes a gain or loss mark.
  Color labelFor(WaterfallStepKind kind) => switch (kind) {
    WaterfallStepKind.gain => barGain,
    WaterfallStepKind.loss => barLoss,
    WaterfallStepKind.start || WaterfallStepKind.total => mutedLabel,
  };
}
