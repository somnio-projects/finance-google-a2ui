// The contract-binding mechanisms, checked against the source.
//
// Split out of `layering_test.dart` so both stay inside the 150-line budget.
// These are the rules from `.claude/rules/frontend/contract-binding.md`: the
// client formats nothing, computes nothing, reads no clock, and interprets no
// server-supplied string.
//
// Each needle is a *mechanism*, not an intent. The point is not that a
// developer would never write `NumberFormat` — it is that if they do, the
// suite is red before review.
//
// Mutation-checked: adding `NumberFormat` to a component makes this file fail.
import 'package:flutter_test/flutter_test.dart';

import 'workspace_sources.dart';

/// Everything that turns a number into text, or text into a number.
///
/// `double.parse` does **not** match `double.tryParse` as a substring, and the
/// `try*` forms are the ones a developer reaches for first — so both spellings
/// of all four are listed. A figure arrives pre-formatted (N-1); a figure is
/// never recomputed (N-2).
const List<String> numberMechanisms = <String>[
  'NumberFormat',
  'package:intl/',
  "import 'dart:math'",
  'toStringAsFixed',
  'toStringAsPrecision',
  'toStringAsExponential',
  'double.parse',
  'double.tryParse',
  'num.parse',
  'num.tryParse',
  'int.parse',
  'int.tryParse',
];

/// Every way of asking the device what time it is (N-13).
const List<String> clockMechanisms = <String>[
  'DateTime.now(',
  'DateTime.timestamp(',
  'Stopwatch(',
];

/// Ways a server-supplied string could become code or a field path (N-5).
const List<String> interpreterMechanisms = <String>[
  "import 'dart:mirrors'",
  'Function.apply(',
  'noSuchMethod(',
  'jsonDecode(',
];

void main() {
  group('binding rules', () {
    late WorkspaceSources sources;

    setUp(() {
      sources = WorkspaceSources.locate();
    });

    test('nothing formats or computes a number', () {
      expect(sources.offenders('app/lib', numberMechanisms), isEmpty);
      expect(sources.offenders('packages', numberMechanisms), isEmpty);
    });

    test('nothing reads the device clock', () {
      // `as_of` is the backend's and travels in the envelope.
      expect(sources.offenders('app/lib', clockMechanisms), isEmpty);
      expect(sources.offenders('packages', clockMechanisms), isEmpty);
    });

    test('nothing interprets a server-supplied string', () {
      // N-5 is a security rule: an interpreter over server input is an
      // injection surface that cannot be documented or covered (ADR-K D-3).
      // `jsonDecode` is legitimate in exactly one place — the transport, which
      // is where a response stops being text and becomes data.
      expect(sources.offenders('app/lib', interpreterMechanisms), isEmpty);
      expect(
        sources.offenders(
          'packages',
          interpreterMechanisms,
          allow: const <String>{
            'packages/finance_api_client/lib/src/finance_api_client.dart',
          },
        ),
        isEmpty,
      );
    });

    test('payload paths are literals, never variables', () {
      // `ViewPayload.text(someVariable)` would be a field path chosen at
      // runtime — the client-side half of the free-form DSL ADR-K D-3
      // rejects. Every reader argument must open with a quote.
      final readers = RegExp(r"\.(text|optionalText|rows)\(\s*([^'\)])");
      final offenders = <String>[];
      sources.under('app/lib').forEach((path, text) {
        if (readers.hasMatch(text)) offenders.add(path);
      });
      expect(offenders, isEmpty);
    });

    test('every component module registers exactly one component', () {
      // A component module lives in its own directory and is named after it;
      // `components/view_component.dart` is the abstraction, not a module.
      final modules = sources.under('app/lib/components')
        ..removeWhere(
          (path, _) =>
              !RegExp(r'components/([a-z_]+)/\1_component\.dart$')
                  .hasMatch(path),
        );
      expect(modules, isNotEmpty);
      for (final entry in modules.entries) {
        expect(
          'void register('.allMatches(entry.value).length,
          equals(1),
          reason: '${entry.key} must expose exactly one register()',
        );
      }
    });
  });
}
