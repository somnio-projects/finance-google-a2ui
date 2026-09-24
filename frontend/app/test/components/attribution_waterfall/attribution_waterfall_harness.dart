/// Mutations of the catalog example, for the contract-violation paths.
///
/// The happy path binds the backend's generated example unchanged; these
/// bend one field each so a test can prove the component *raises* rather
/// than reconstructs (N-3). Kept beside the suites that use them rather than
/// copy-pasted into both — a fixture that differs between two halves of a
/// class's tests is how the halves stop agreeing.
library;

/// A copy of [example] whose first bucket reports [direction].
Map<String, dynamic> withDirection(
  Map<String, dynamic> example,
  String direction,
) {
  final buckets = (example['buckets'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  return <String, dynamic>{
    ...example,
    'buckets': <Map<String, dynamic>>[
      <String, dynamic>{...buckets.first, 'direction': direction},
      ...buckets.skip(1),
    ],
  };
}

/// A copy of [example] whose opening level is not a decimal string.
Map<String, dynamic> withBadLevel(Map<String, dynamic> example) {
  final start = example['start'] as Map<String, dynamic>;
  final amount = start['amount'] as Map<String, dynamic>;
  return <String, dynamic>{
    ...example,
    'start': <String, dynamic>{
      ...start,
      'amount': <String, dynamic>{...amount, 'amount': 'not a decimal'},
    },
  };
}
