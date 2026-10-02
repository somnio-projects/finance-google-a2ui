/// Fixtures for the allocation suites.
///
/// The **happy path binds the backend's generated example unchanged**, read
/// through `CatalogSnapshot` — these are the shapes the catalog declares but
/// the example does not carry (an empty portfolio, a single holding, more
/// categories than the design's ramp has colours). Kept beside the suites
/// that use them rather than copy-pasted into each, which is how two halves
/// of a class's tests stop agreeing.
library;

import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';

/// A copy of [example] with no categories at all.
///
/// The catalog declares `categories` with `state: "empty"`, so this is a
/// state the contract has rather than one the test invented.
Map<String, dynamic> withNoCategories(Map<String, dynamic> example) =>
    <String, dynamic>{...example, 'categories': const <Map<String, dynamic>>[]};

/// A copy of [example] carrying only its first category.
Map<String, dynamic> withOneCategory(Map<String, dynamic> example) {
  final categories = (example['categories'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  return <String, dynamic>{
    ...example,
    'categories': <Map<String, dynamic>>[categories.first],
  };
}

/// A copy of [example] whose first category's weight is not a decimal string.
///
/// Drives the N-3 path through `geometry` rather than through `text`: the
/// component must raise, naming the path, rather than reconstruct the share.
Map<String, dynamic> withBadWeight(Map<String, dynamic> example) {
  final categories = (example['categories'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final first = categories.first;
  return <String, dynamic>{
    ...example,
    'categories': <Map<String, dynamic>>[
      <String, dynamic>{
        ...first,
        'weight': <String, dynamic>{
          ...first['weight']! as Map<String, dynamic>,
          'value': 'not a decimal',
        },
      },
      ...categories.skip(1),
    ],
  };
}

/// [count] categories, more than the design's six-colour ramp.
///
/// The catalog's `top_n` goes to 20 and `include_other` adds a row on top, so
/// 21 is reachable from declared options alone — the ramp must wrap rather
/// than run out.
List<AllocationCategory> manyCategories(int count) => <AllocationCategory>[
  for (var index = 0; index < count; index++)
    AllocationCategory(
      key: 'K$index',
      label: 'Category $index',
      valueDisplay: r'$1,000.00',
      weightDisplay: '7.14%',
      weight: 1 / count,
    ),
];

/// A small, hand-built model for the widget suites that do not need the
/// catalog example's five rows.
const AllocationData twoCategories = AllocationData(
  title: 'Allocation by holding',
  totalLabel: 'Total market value',
  totalDisplay: r'$65,038.60',
  categories: <AllocationCategory>[
    AllocationCategory(
      key: 'BTC',
      label: 'Bitcoin',
      valueDisplay: r'$38,550.00',
      weightDisplay: '59.27%',
      weight: 0.5927249356535964,
    ),
    AllocationCategory(
      key: 'other',
      label: 'Other',
      valueDisplay: r'$1,527.60',
      weightDisplay: '2.35%',
      weight: 0.0234875904462888,
    ),
  ],
);
