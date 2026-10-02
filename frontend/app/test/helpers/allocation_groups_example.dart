/// The `groups[]` block of the allocation example, its own file.
///
/// Split off only because inlining it pushed `allocation_example.dart` past
/// the 150-line budget. Same fixture rule: this is a **verbatim copy** of the
/// generated snapshot, and the snapshot is the contract.
/// The toggle's three segments, as the backend publishes them.
const List<Map<String, dynamic>> allocationGroupsExample =
    <Map<String, dynamic>>[
      <String, dynamic>{
        'label': 'By holding',
        'selected': true,
        'value': 'holding',
      },
      <String, dynamic>{
        'label': 'By asset class',
        'selected': false,
        'value': 'asset_class',
      },
      <String, dynamic>{
        'label': 'By sector',
        'selected': false,
        'value': 'sector',
      },
    ];
