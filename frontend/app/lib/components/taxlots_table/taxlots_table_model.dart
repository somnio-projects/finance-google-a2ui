import 'package:equatable/equatable.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term.dart';

/// One lot the proposed sale consumes, already formatted by the backend.
///
/// Every money field is a `String`. There is no `double` here to be tempted
/// into arithmetic with, which is prohibition N-2 made structural rather than
/// remembered — the shape `HoldingsAllocationRow` established.
class TaxLot extends Equatable {
  /// Creates a lot.
  const TaxLot({
    required this.label,
    required this.acquiredOnDisplay,
    required this.holdingPeriodDisplay,
    required this.unitsDisplay,
    required this.costBasisDisplay,
    required this.proceedsDisplay,
    required this.gainLossDisplay,
    required this.term,
    required this.termLabel,
    required this.trend,
    required this.fullySold,
  });

  /// The payload's `label`, e.g. `lot-nvda-01`. Row identity, not a figure.
  final String label;

  /// The payload's `acquired_on_display`.
  ///
  /// The *display* twin, not the raw `acquired_on`: the backend added it
  /// after spec `frontend/0003` OD-1 asked for it, and re-spelling a date
  /// here would be formatting (N-1) — `intl` is one of the mechanisms
  /// `binding_rules_test.dart` fails on.
  final String acquiredOnDisplay;

  /// The payload's `lots[].holding_period_display`, e.g. `5.5 yr`.
  ///
  /// The duration the kit draws beside the term pill. It arrives as a string
  /// because a duration is `as_of - acquired_on` and this app has no clock to
  /// subtract with — reading the device clock is N-13, and
  /// `binding_rules_test.dart` fails on the three mechanisms for it, in
  /// comments too. The backend words it, and the form it takes always agrees
  /// with [term] (spec `backend/0049` OD-2).
  final String holdingPeriodDisplay;

  /// The payload's `units_display` — the *Shares* column.
  ///
  /// Again the display twin. The raw `units` (`60.0000`) is what N-4 forbids
  /// putting on screen, and the column could not be drawn at all until this
  /// field existed (`frontend/0003` OD-2).
  final String unitsDisplay;

  /// The payload's `cost_basis.display`.
  final String costBasisDisplay;

  /// The payload's `proceeds.display` — what the design calls *Market value*
  /// and the contract calls proceeds (spec `frontend/0027` OD-1).
  final String proceedsDisplay;

  /// The payload's `gain_loss.display`, sign already included.
  final String gainLossDisplay;

  /// The payload's `term`, as an enum.
  final TaxLotTerm term;

  /// The human label for [term], read from the matching `by_term` entry.
  ///
  /// Server-written, never a constant in this app: the backend already says
  /// `"Short-term"` / `"Long-term"` and the `locale` option can change it.
  final String termLabel;

  /// The payload's `trend`, as an enum — which colour the gain/loss takes.
  final TaxLotTrend trend;

  /// The payload's `fully_sold` — whether this sale consumes the lot whole.
  ///
  /// The contract publishes it as a flag with `state: variant`, which is the
  /// catalog's own word for "this changes how the row looks", and it is what
  /// the design's ticked, tinted row means. It is a **state, not a
  /// control**: the view declares no action and no selection option, so
  /// nothing on the card can change it (OD-3).
  final bool fullySold;

  @override
  List<Object?> get props => <Object?>[
    label,
    acquiredOnDisplay,
    holdingPeriodDisplay,
    unitsDisplay,
    costBasisDisplay,
    proceedsDisplay,
    gainLossDisplay,
    term,
    termLabel,
    trend,
    fullySold,
  ];
}

/// One half of the realised result, split by holding period.
class TaxLotTermSplit extends Equatable {
  /// Creates a split.
  const TaxLotTermSplit({
    required this.term,
    required this.label,
    required this.realizedDisplay,
  });

  /// Which bucket this half is.
  final TaxLotTerm term;

  /// The payload's `by_term[].label`, e.g. `Long-term`.
  final String label;

  /// The payload's `by_term[].realized.display`.
  final String realizedDisplay;

  @override
  List<Object?> get props => <Object?>[term, label, realizedDisplay];
}
