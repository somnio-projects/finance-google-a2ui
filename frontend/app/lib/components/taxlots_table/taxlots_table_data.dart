import 'package:equatable/equatable.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';

/// Everything the card draws, read once from the payload.
///
/// Split out of `taxlots_table_model.dart` when the lot grew its display
/// twins and its flag: two classes about a *row* and one about the *card* is
/// the seam the 150-line budget found.
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

  /// The payload's `title`, in the design's header slot (OD-4).
  final String title;

  /// The payload's `subtitle`, e.g. `Sell 75 NVDA under FIFO`.
  ///
  /// Drawn under the title rather than dropped: it is a server-written string
  /// and N-9 does not let this client decide it is not worth showing.
  final String subtitle;

  /// The payload's `realized.label`, the footer's caption.
  ///
  /// This is the string that differs between the design's two footer states
  /// — *Realized gain if sold* and *Realized on selected sale* — and it is
  /// the backend's to choose, not this card's.
  final String realizedLabel;

  /// The payload's `realized.amount.display`, the footer's total.
  final String realizedDisplay;

  /// The payload's `cost_basis.label` — the caption over that column.
  ///
  /// Server-written, so it follows the view's `locale` option. A Dart
  /// constant here would not.
  final String costBasisLabel;

  /// The payload's `proceeds.label` — the caption over the column the design
  /// calls *Market value* (OD-1).
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
