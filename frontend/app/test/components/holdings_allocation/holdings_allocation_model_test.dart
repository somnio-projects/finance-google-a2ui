import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'holdings_allocation_harness.dart';

void main() {
  group(AllocationCategory, () {
    const bitcoin = AllocationCategory(
      key: 'BTC',
      label: 'Bitcoin',
      valueDisplay: r'$38,550.00',
      weightDisplay: '59.27%',
      weight: 0.5927249356535964,
    );

    test('is a value over every field it carries', () {
      expect(bitcoin, equals(twoCategories.categories.first));
      expect(bitcoin.hashCode, equals(twoCategories.categories.first.hashCode));
    });

    test('distinguishes the display string from the share', () {
      // The two travel on disjoint paths and neither is derived from the
      // other, so a category whose *string* changed is a different value even
      // though its geometry is identical — and vice versa. That is what makes
      // "the client never recomputes a figure" structural rather than a note.
      const restated = AllocationCategory(
        key: 'BTC',
        label: 'Bitcoin',
        valueDisplay: r'$38,550.00',
        weightDisplay: '59.3%',
        weight: 0.5927249356535964,
      );
      const resized = AllocationCategory(
        key: 'BTC',
        label: 'Bitcoin',
        valueDisplay: r'$38,550.00',
        weightDisplay: '59.27%',
        weight: 0.6,
      );
      expect(bitcoin, isNot(equals(restated)));
      expect(bitcoin, isNot(equals(resized)));
    });
  });

  group(AllocationData, () {
    test('is a value over its fields', () {
      expect(twoCategories, equals(twoCategories));
      const other = AllocationData(
        title: 'Allocation by sector',
        totalLabel: 'Total market value',
        totalDisplay: r'$65,038.60',
        categories: <AllocationCategory>[],
      );
      expect(twoCategories, isNot(equals(other)));
      expect(twoCategories.hashCode, isNot(equals(other.hashCode)));
    });

    test('hands the donut the shares in payload order', () {
      // N-10: the ring's slice *i* is the legend's row *i* is the payload's
      // category *i*, and nothing in between sorts.
      expect(
        twoCategories.weights,
        equals(<double>[0.5927249356535964, 0.0234875904462888]),
      );
      expect(twoCategories.isEmpty, isFalse);
    });

    test('reports an empty portfolio, which the contract declares', () {
      const empty = AllocationData(
        title: 'Allocation by holding',
        totalLabel: 'Total market value',
        totalDisplay: r'$0.00',
        categories: <AllocationCategory>[],
      );
      expect(empty.isEmpty, isTrue);
      expect(empty.weights, isEmpty);
    });
  });
}
