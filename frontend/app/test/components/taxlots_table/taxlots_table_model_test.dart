import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
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
    TaxLotsTableData data({String title = 'Tax lots this sale consumes'}) =>
        TaxLotsTableData(
          title: title,
          subtitle: 'Sell 0.5 BTC under FIFO',
          realizedLabel: 'Realised P/L',
          realizedDisplay: r'+$9,505.00',
          costBasisLabel: 'Cost basis',
          proceedsLabel: 'Proceeds',
          lots: <TaxLot>[harness.lot()],
          splits: harness.splits,
        );

    test('two cards with the same payload are equal', () {
      expect(data(), data());
      expect(data().hashCode, data().hashCode);
    });

    test('a different title is a different card', () {
      expect(data(), isNot(data(title: 'Something else')));
    });
  });
}
