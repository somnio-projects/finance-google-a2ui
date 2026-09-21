/// Fixtures shared by the tax-lot suite.
///
/// The *payload* fixtures are derived from the generated catalog snapshot
/// rather than written out (rule §5), so a backend rename turns the suite
/// red. Only the mutations a failure path needs are spelled here.
library;

import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';

/// The example with one member of `lots` altered.
Map<String, dynamic> withLotField(
  Map<String, dynamic> example,
  String field,
  Object? value,
) {
  final lots = (example['lots']! as List<dynamic>).cast<Map<String, dynamic>>();
  final first = Map<String, dynamic>.from(lots.first);
  if (value == null) {
    first.remove(field);
  } else {
    first[field] = value;
  }
  return <String, dynamic>{
    ...example,
    'lots': <Map<String, dynamic>>[first, ...lots.skip(1)],
  };
}

/// The example with one member of `by_term` altered.
Map<String, dynamic> withTermField(
  Map<String, dynamic> example,
  String field,
  Object? value,
) {
  final halves = (example['by_term']! as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final first = Map<String, dynamic>.from(halves.first)..[field] = value;
  return <String, dynamic>{
    ...example,
    'by_term': <Map<String, dynamic>>[first, ...halves.skip(1)],
  };
}

/// The example with no lots at all — the design's empty state.
Map<String, dynamic> withoutLots(Map<String, dynamic> example) =>
    <String, dynamic>{...example, 'lots': <Map<String, dynamic>>[]};

/// A lot built from parts, for a widget test that needs one value changed.
///
/// The card's tests bind the real example; this exists for the two cases
/// the published example cannot show — a `down` trend, and a short-term lot
/// in the first row.
TaxLot lot({
  TaxLotTerm term = TaxLotTerm.long,
  TaxLotTrend trend = TaxLotTrend.up,
  String termLabel = 'Long-term',
  String gainLossDisplay = r'+$8,925.00',
}) => TaxLot(
  label: 'lot-btc-01',
  acquiredOn: '2025-01-13',
  costBasisDisplay: r'$18,060.00',
  proceedsDisplay: r'$26,985.00',
  gainLossDisplay: gainLossDisplay,
  term: term,
  termLabel: termLabel,
  trend: trend,
);

/// The two halves the footer and the legend draw.
const List<TaxLotTermSplit> splits = <TaxLotTermSplit>[
  TaxLotTermSplit(
    term: TaxLotTerm.short,
    label: 'Short-term',
    realizedDisplay: r'+$580.00',
  ),
  TaxLotTermSplit(
    term: TaxLotTerm.long,
    label: 'Long-term',
    realizedDisplay: r'+$8,925.00',
  ),
];
