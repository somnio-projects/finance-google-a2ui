import 'package:equatable/equatable.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term.dart';

/// One lot the proposed sale consumes, already formatted by the backend.
///
/// Every money field is a `String`. There is no `double` here to be tempted
/// into arithmetic with, which is prohibition N-2 made structural rather
/// than remembered — the shape `HoldingsAllocationRow` established.
class TaxLot extends Equatable {
  /// Creates a lot.
  const TaxLot({
    required this.label,
    required this.acquiredOn,
    required this.costBasisDisplay,
    required this.proceedsDisplay,
    required this.gainLossDisplay,
    required this.term,
    required this.termLabel,
    required this.trend,
  });

  /// The payload's `label`, e.g. `lot-btc-01`. Row identity, not a figure.
  final String label;

  /// The payload's `acquired_on`, e.g. `2025-01-13`.
  ///
  /// Rendered exactly as it arrives. The design shows `Mar 12, 2021`, and
  /// re-spelling a date is formatting — `intl` is one of the mechanisms
  /// `binding_rules_test.dart` fails on. Spec `frontend/0003` OD-1 asks the
  /// backend for an `acquired_on_display` beside it.
  final String acquiredOn;

  /// The payload's `cost_basis.display`.
  final String costBasisDisplay;

  /// The payload's `proceeds.display` — what the sale realises for this lot.
  final String proceedsDisplay;

  /// The payload's `gain_loss.display`, sign already included.
  final String gainLossDisplay;

  /// The payload's `term`, as an enum.
  final TaxLotTerm term;

  /// The human label for [term], read from the matching `by_term` entry.
  ///
  /// Server-written, never a constant in this app: the backend already says
  /// `"Short-term"` / `"Long-term"` and the locale option can change it.
  final String termLabel;

  /// The payload's `trend`, as an enum — which colour the gain/loss takes.
  final TaxLotTrend trend;

  @override
  List<Object?> get props => <Object?>[
    label,
    acquiredOn,
    costBasisDisplay,
    proceedsDisplay,
    gainLossDisplay,
    term,
    termLabel,
    trend,
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

/// Everything the card draws, read once from the payload.
class TaxLotsTableData extends Equatable {
  /// Creates the card's data.
  const TaxLotsTableData({
    required this.title,
    required this.subtitle,
    required this.realizedLabel,
    required this.realizedDisplay,
    required this.costBasisLabel,
    required this.proceedsLabel,
    required this.lots,
    required this.splits,
  });

  /// The payload's `title`.
  final String title;

  /// The payload's `subtitle`, e.g. `Sell 0.5 BTC under FIFO`.
  final String subtitle;

  /// The payload's `realized.label`, the footer's caption.
  final String realizedLabel;

  /// The payload's `realized.amount.display`, the footer's total.
  final String realizedDisplay;

  /// The payload's `cost_basis.label` — the caption over that column.
  ///
  /// Server-written, so it follows the view's `locale` option. A Dart
  /// constant here would not.
  final String costBasisLabel;

  /// The payload's `proceeds.label` — the caption over that column.
  final String proceedsLabel;

  /// The lots, **in the order the backend sent them** (N-10).
  final List<TaxLot> lots;

  /// The `by_term` halves, also in arrival order.
  final List<TaxLotTermSplit> splits;

  @override
  List<Object?> get props => <Object?>[
    title,
    subtitle,
    realizedLabel,
    realizedDisplay,
    costBasisLabel,
    proceedsLabel,
    lots,
    splits,
  ];
}
