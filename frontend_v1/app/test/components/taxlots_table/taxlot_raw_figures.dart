/// The N-4 half of the contract, read out of the generated catalog.
library;

/// Every raw figure the catalog marks `binding: raw` in the published
/// example, read out of the snapshot rather than typed.
///
/// N-4's half of the contract is "no raw member reaches a `Text`", and a
/// hand-written list of five strings proves it for five strings. The
/// snapshot already says which paths are raw, so the assertion can be
/// universally quantified over them — and a raw field added by the backend
/// joins it without anybody remembering to.
List<String> rawFigures(Map<String, dynamic> entry) {
  final example = entry['example']! as Map<String, dynamic>;
  final paths = <String>[
    for (final field in (entry['fields']! as List<dynamic>))
      if ((field as Map<String, dynamic>)['binding'] == 'raw')
        field['path']! as String,
  ];
  final found = <String>{};
  for (final path in paths) {
    found.addAll(_resolve(example, path.split('.')));
  }
  if (found.isEmpty) {
    throw StateError('no raw figures in the example; the walk is wrong');
  }
  return found.toList();
}

/// Reads [segments] out of [node], following `lots[]` into every row.
Iterable<String> _resolve(Object? node, List<String> segments) sync* {
  if (segments.isEmpty) {
    if (node is String) yield node;
    if (node is num) yield '$node';
    return;
  }
  final head = segments.first;
  final rest = segments.sublist(1);
  if (head.endsWith('[]')) {
    final rows =
        (node! as Map<String, dynamic>)[head.substring(0, head.length - 2)];
    for (final row in rows! as List<dynamic>) {
      yield* _resolve(row, rest);
    }
    return;
  }
  yield* _resolve((node! as Map<String, dynamic>)[head], rest);
}
