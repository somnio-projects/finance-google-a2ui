import 'package:equatable/equatable.dart';
import 'package:finance_charts/src/chart_geometry.dart';

/// What a waterfall step is, which decides how it is drawn and coloured.
///
/// The kind is **given**, never inferred by comparing numbers: the backend's
/// `buckets[].direction` enum says whether a contribution moved the total up
/// or down, and the contract is explicit that the client uses that rather
/// than the sign of a figure (`.claude/rules/frontend/contract-binding.md`).
enum WaterfallStepKind {
  /// The opening total. Drawn from the axis floor to its level.
  start,

  /// A contribution that raised the running total.
  gain,

  /// A contribution that lowered it.
  loss,

  /// The closing total. Drawn from the axis floor to its level.
  total,
}

/// One step of a waterfall, as the layout needs it.
///
/// [level] is the running total **after** this step: `start.amount.amount`
/// for the opener, `buckets[i].cumulative.amount` for each contribution and
/// `end.amount.amount` for the closer. A contribution's bar is then bounded
/// by two given levels, so the layout never adds or subtracts a figure — it
/// only compares two the backend already computed (prohibition N-2).
class WaterfallStep extends Equatable {
  /// Creates a step.
  const WaterfallStep({
    required this.key,
    required this.kind,
    required this.level,
  });

  /// The payload's `key` — `BTC`, or the synthetic key a total carries.
  ///
  /// It is what a tap reports back, because `drill.attribution.v1` takes the
  /// raw symbol as its argument.
  final String key;

  /// See [WaterfallStepKind].
  final WaterfallStepKind kind;

  /// The running total after this step, from the payload's raw `amount`.
  ///
  /// A raw decimal is legitimate here and only here: it is chart geometry,
  /// which is the use ADR-K reserves the raw member for. It must never reach
  /// a `Text` (N-4).
  final double level;

  @override
  List<Object?> get props => <Object?>[key, kind, level];
}

/// One painted bar, in pixels.
class WaterfallBar extends Equatable {
  /// Creates a bar.
  const WaterfallBar({
    required this.index,
    required this.step,
    required this.rect,
  });

  /// The step's position, which is also its band.
  final int index;

  /// The step this bar draws.
  final WaterfallStep step;

  /// Where it is drawn.
  final ChartRect rect;

  @override
  List<Object?> get props => <Object?>[index, step, rect];
}

/// The dashed run from one bar's exit level to the next bar's band.
class WaterfallConnector extends Equatable {
  /// Creates a connector.
  const WaterfallConnector({required this.from, required this.to});

  /// The centre of the band it leaves, at that step's running total.
  final ChartPoint from;

  /// The centre of the next band, at the same level — connectors are always
  /// horizontal, because they show where the next bar starts from.
  final ChartPoint to;

  @override
  List<Object?> get props => <Object?>[from, to];
}
