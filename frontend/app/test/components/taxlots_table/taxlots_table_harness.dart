/// Fixtures shared by the tax-lot suite.
///
/// The *payload* fixtures are derived from the generated catalog snapshot
/// rather than written out (rule §5), so a backend rename turns the suite
/// red. Only the mutations a failure path or an edge case needs are spelled
/// here.
library;

import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_data.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_footer.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

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
/// The card's tests bind the real example; this exists for the cases the
/// published example cannot show — a `down` trend, a ticked row, and a
/// short-term lot in the first position. The default duration is the
/// artboard's own `5.5 yr`, which pairs with the default `long` term.
TaxLot lot({
  TaxLotTerm term = TaxLotTerm.long,
  TaxLotTrend trend = TaxLotTrend.up,
  String termLabel = 'Long-term',
  String gainLossDisplay = r'+$8,925.00',
  String acquiredOnDisplay = '03/12/2021',
  String unitsDisplay = '30',
  String holdingPeriodDisplay = '5.5 yr',
  bool fullySold = false,
}) => TaxLot(
  label: 'lot-nvda-01',
  acquiredOnDisplay: acquiredOnDisplay,
  holdingPeriodDisplay: holdingPeriodDisplay,
  unitsDisplay: unitsDisplay,
  costBasisDisplay: r'$18,060.00',
  proceedsDisplay: r'$26,985.00',
  gainLossDisplay: gainLossDisplay,
  term: term,
  termLabel: termLabel,
  trend: trend,
  fullySold: fullySold,
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

/// A card's data built from [lots], for the edge cases the example cannot
/// express — one lot, eight lots, a title nobody sized the header for.
TaxLotsTableData cardData({
  required List<TaxLot> lots,
  String title = 'Tax lots this sale consumes',
}) => TaxLotsTableData(
  title: title,
  subtitle: 'Sell 75 NVDA under FIFO',
  realizedLabel: 'Realised P/L',
  realizedDisplay: r'+$30,349.50',
  realizedTrend: TaxLotTrend.up,
  costBasisLabel: 'Cost basis',
  proceedsLabel: 'Proceeds',
  lots: lots,
  splits: splits,
);

/// The display string every footer test looks for.
const String footerTotalDisplay = r'+$9,505.00';

/// Pumps the footer on its own, at the kit's content width.
///
/// Shared because two files ask about it — what it draws, and what colour it
/// draws the total in — and a fixture that differs between two halves of one
/// class's tests is how the halves stop agreeing (`frontend/testing.md` §3).
Future<void> pumpFooter(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  List<TaxLotTermSplit> halves = splits,
  String label = 'Realised P/L',
  TaxLotTrend trend = TaxLotTrend.up,
}) => tester.pumpApp(
  Scaffold(
    body: Center(
      child: SizedBox(
        width: 600,
        child: TaxLotsTableFooter(
          label: label,
          totalDisplay: footerTotalDisplay,
          trend: trend,
          splits: halves,
        ),
      ),
    ),
  ),
  brightness: brightness,
);
