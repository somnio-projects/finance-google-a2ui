import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_data.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'taxlots_table_harness.dart' as harness;

/// The model's equality, which the card relies on to rebuild only when the
/// payload actually changed.
void main() {
  group(TaxLot, () {
    test('two lots with the same fields are equal', () {
      expect(harness.lot(), harness.lot());
      expect(harness.lot().hashCode, harness.lot().hashCode);
    });

    test('a different term, trend or figure is a different lot', () {
      expect(harness.lot(), isNot(harness.lot(term: TaxLotTerm.short)));
      expect(harness.lot(), isNot(harness.lot(trend: TaxLotTrend.down)));
      expect(harness.lot(), isNot(harness.lot(termLabel: 'Other')));
      expect(harness.lot(), isNot(harness.lot(gainLossDisplay: r'-$1.00')));
      expect(harness.lot(), isNot(harness.lot(unitsDisplay: '31')));
      expect(harness.lot(), isNot(harness.lot(acquiredOnDisplay: '1/1/2020')));
    });

    test('a lot the sale consumes whole is a different lot', () {
      // `fully_sold` is what the kit's ticked, tinted row draws, so a card
      // that ignored it in equality would not rebuild when it changed.
      expect(harness.lot(), isNot(harness.lot(fullySold: true)));
    });
  });

  group(TaxLotTermSplit, () {
    test('two halves with the same fields are equal', () {
      const one = TaxLotTermSplit(
        term: TaxLotTerm.long,
        label: 'Long-term',
        realizedDisplay: r'+$8,925.00',
      );
      expect(one, harness.splits.last);
      expect(one, isNot(harness.splits.first));
    });
  });

  group(TaxLotsTableData, () {
    test('two cards with the same payload are equal', () {
      final lots = <TaxLot>[harness.lot()];
      expect(harness.cardData(lots: lots), harness.cardData(lots: lots));
      expect(
        harness.cardData(lots: lots).hashCode,
        harness.cardData(lots: lots).hashCode,
      );
    });

    test('a different title is a different card', () {
      final lots = <TaxLot>[harness.lot()];
      expect(
        harness.cardData(lots: lots),
        isNot(harness.cardData(lots: lots, title: 'Something else')),
      );
    });
  });
}
