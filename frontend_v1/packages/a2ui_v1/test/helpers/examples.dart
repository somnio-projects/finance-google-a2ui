import 'dart:convert';
import 'dart:io';

import 'package:a2ui_v1/a2ui_v1.dart';

/// The wire contract, read from the repository rather than copied: a copy
/// is the thing that goes stale (`.claude/rules/frontend/testing.md` §5).
const String examplesDir = '../../../docs/a2ui/v1.0/examples';

/// The keys a renderer-to-agent message is made of.
const Set<String> rendererKeys = <String>{
  'action',
  'callAgentFunction',
  'rendererFunctionResponse',
  'error',
};

/// Every example file, sorted, by base name.
List<String> exampleNames() {
  final names =
      Directory(examplesDir)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .map((file) => file.uri.pathSegments.last)
          .toList()
        ..sort();
  if (names.length < 6) {
    // Anti-vacuity: an empty walk would pass every quantified assertion.
    throw StateError('expected the six v1.0 examples, found $names');
  }
  return names;
}

/// The decoded DataPart in [name].
Map<String, Object?> example(String name) =>
    jsonDecode(File('$examplesDir/$name').readAsStringSync())
        as Map<String, Object?>;

/// Whether [name] holds renderer-to-agent messages.
bool isRendererToAgent(String name) {
  final data = example(name)['data']! as List<Object?>;
  final first = data.first! as Map<String, Object?>;
  return first.keys.any(rendererKeys.contains);
}

/// The provisional catalog fixture (ADR-M D-4).
Catalog provisionalCatalog() => Catalog.fromJson(
  jsonDecode(
    File('test/fixtures/finance.catalog.provisional.json').readAsStringSync(),
  ),
);

/// The messages of [name], decoded, failing the test on any failure.
List<AgentMessage> agentMessages(String name) => <AgentMessage>[
  for (final decoded in decodeAgentDataPart(example(name)))
    switch (decoded) {
      DecodedMessage(:final message) => message,
      DecodeFailure(:final error) => throw StateError('$name: $error'),
    },
];
