import 'dart:io';

import 'package:a2ui_v1/a2ui_v1.dart';
// The transport's decoder, not a second one: the binding rules allow a JSON
// decoder in exactly the transport, and a fixture reader is no reason to
// widen that allowance (`binding_rules_test.dart::nothing interprets a
// server-supplied string`).
import 'package:finance_api_client/finance_api_client.dart'
    show decodeJsonObject;

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

/// Every example file, by base name, in directory order.
List<String> exampleNames() {
  final names = Directory(examplesDir)
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .map((file) => file.uri.pathSegments.last)
      .toList();
  if (names.length < 6) {
    // Anti-vacuity: an empty walk would pass every quantified assertion.
    throw StateError('expected the six v1.0 examples, found $names');
  }
  return names;
}

/// The decoded DataPart in [name].
Map<String, Object?> example(String name) =>
    _decode(File('$examplesDir/$name'));

/// Whether [name] holds renderer-to-agent messages.
bool isRendererToAgent(String name) {
  final data = example(name)['data']! as List<Object?>;
  final first = data.first! as Map<String, Object?>;
  return first.keys.any(rendererKeys.contains);
}

/// The catalog the backend generates (ADR-M D-4/D-5), read in place.
Catalog financeCatalog() => Catalog.fromJson(
  _decode(File('../../../docs/a2ui/v1.0/finance.catalog.json')),
);

/// The messages of [name], decoded, failing the test on any failure.
List<AgentMessage> agentMessages(String name) => <AgentMessage>[
  for (final decoded in decodeAgentDataPart(example(name)))
    switch (decoded) {
      DecodedMessage(:final message) => message,
      DecodeFailure(:final error) => throw StateError('$name: $error'),
    },
];

Map<String, Object?> _decode(File file) =>
    decodeJsonObject(file.readAsStringSync()) ??
    (throw StateError('${file.path} is not a JSON object'));
