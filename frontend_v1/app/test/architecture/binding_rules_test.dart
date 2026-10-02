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

import 'binding_mechanisms.dart';
import 'workspace_sources.dart';

void main() {
  group('binding rules', () {
    late WorkspaceSources sources;

    setUp(() {
      sources = WorkspaceSources.locate();
    });

    test('nothing formats or computes a number', () {
      expect(sources.offenders('app/lib', numberMechanisms), isEmpty);
      // `rawDecimal` is the one seam that turns the contract's raw `amount`
      // into a position on a canvas, and it is allowed here for exactly the
      // reason `jsonDecode` is allowed in the transport below: the mechanism
      // is legitimate in one named file and nowhere else. A responsive chart
      // cannot get its value-to-pixel mapping from a server that does not
      // know the width it will be laid out in (ADR-L D-14). The allowance is
      // per file, so the file is five lines long on purpose.
      expect(
        sources.offenders('packages', numberMechanisms, allow: numberAllowed),
        isEmpty,
      );
    });

    test('the geometry seam is the only exemption', () {
      // The claim ADR-L D-14, both rule files and SECURITY.md all make, as an
      // assertion rather than prose. The allowance is what makes a chart
      // possible and it is also the one hole in the rule, so its *size* is
      // the thing worth pinning: a second entry here is a second hole.
      expect(numberAllowed, hasLength(1));
      expect(numberAllowed.single, geometrySeam);
      // And it still names a file that exists — an allowance that outlives
      // the file it excused is a hole nobody can see.
      expect(sources.under('packages').keys, contains(geometrySeam));
    });

    test('nothing reads the device clock', () {
      // `as_of` is the backend's and travels in the envelope. The one
      // allowance is the A2UI v1.0 `action.timestamp`, which the schema
      // requires and nobody reads as a figure (ADR-M D-7) — allowed by path,
      // and the allowance's size pinned like the geometry seam's.
      const clockAllowed = <String>{'app/lib/a2ui/action_clock.dart'};
      expect(clockAllowed, hasLength(1));
      expect(sources.under('app/lib').keys, contains(clockAllowed.single));
      expect(
        sources.offenders('app/lib', clockMechanisms, allow: clockAllowed),
        isEmpty,
      );
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
            'packages/finance_api_client/lib/src/response_decoder.dart',
            // The agent path's decoder. Same allowance and same reason: an
            // event stream stops being text and becomes data here, inside the
            // transport, and nowhere above it.
            'packages/finance_api_client/lib/src/event_stream.dart',
          },
        ),
        isEmpty,
      );
    });

    test('payload paths are literals, never variables', () {
      // `ViewPayload.text(someVariable)` would be a field path chosen at
      // runtime — the client-side half of the free-form DSL ADR-K D-3
      // rejects. Every reader argument must open with a quote. `geometry`
      // is in this list from the day it existed: a reader added without its
      // entry here is a hole in the rule, which is how a rule like this
      // usually fails.
      // Every accessor `ViewPayload` exposes is named here. An accessor added
      // to the reader and forgotten here would be a hole in N-5 exactly the
      // width of the new method, so the list is kept in step with the class.
      final readers = RegExp(
        r"\.(text|optionalText|rows|strings|geometry)\(\s*([^'\)])",
      );
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
