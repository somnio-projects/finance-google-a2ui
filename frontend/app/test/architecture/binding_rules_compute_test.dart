// N-2 (never compute a figure) and N-10 (never reorder rows), as mechanisms.
//
// Split from `binding_rules_test.dart` by concern — that file holds the
// *formatting* half (N-1, N-4) and both have to stay inside the 150-line
// budget. It exists because the formatting half never covered these two: every
// one of its twelve needles turns a number into text or text into a number,
// and none of them aggregates, rounds or re-ranks. `frontend/SECURITY.md`
// nevertheless claimed "no arithmetic ... on the client" and cited that test,
// which was an over-claim; this file is half of the correction and the
// narrowed wording in SECURITY.md is the other half.
//
// **What is deliberately NOT needled: the bare operators `+ - * /`.** They
// cannot be matched as substrings without matching string concatenation,
// `super + 1`-style offsets and every comment containing a hyphen, so a needle
// for them would be noise rather than a gate. That limit is written down here
// and in SECURITY.md rather than papered over — the rule enforces the
// aggregation and rounding *mechanisms*, and review covers bare arithmetic.
//
// Mutation-checked: adding `rows.sort()` to a component makes this file fail.
import 'package:flutter_test/flutter_test.dart';

import 'workspace_sources.dart';

/// Aggregating, rounding and re-ranking — the mechanisms that would let the
/// client produce a figure (N-2) or change the order rows arrived in (N-10).
///
/// `cumulative`, `spread`, `by_term` and `markers` are all supplied by the
/// backend, and `sort`, `top_n`, `methods` and `lot_method` are *options* the
/// server owns. So none of these has a legitimate use on a payload.
const List<String> computationMechanisms = <String>[
  '.fold(',
  '.reduce(',
  '.sort(',
  '.round()',
  '.floor()',
  '.ceil()',
  '.abs()',
  '.toInt()',
  '.toDouble()',
];

/// Files allowed to use a [computationMechanisms] needle, with the reason.
///
/// Both are whole-file carve-outs, which is the coarseness the shared
/// `offenders` helper offers; both are also files that touch no payload
/// figure, which is why the coarseness costs nothing here.
///
///  * `views_repository.dart` sorts **view ids and option pairs** to build a
///    stable cache key, so `?view=a&view=b` and `?view=b&view=a` are one
///    entry. It never sorts payload rows — N-10 is about the rows a component
///    renders, and this file renders nothing.
///  * `result_test.dart` exercises `Result.fold(onOk:, onErr:)`, the sealed
///    union's combinator. It is not a numeric fold.
///  * `band_scale.dart` rounds a **pixel** down to a band index, to answer
///    "which step did this tap land on". `finance_charts` never sees a
///    payload — it is handed coordinates and hands back rectangles — so N-2's
///    premise, that none of these has a legitimate use *on a payload figure*,
///    simply does not reach it. The figures a reader sees are `*.display`
///    strings that never enter this package (ADR-L D-13).
const Set<String> computationAllowed = <String>{
  'packages/finance_views_repository/lib/src/views_repository.dart',
  'packages/finance_core/test/src/result_test.dart',
  'packages/finance_charts/lib/src/band_scale.dart',
};

void main() {
  group('computation rules', () {
    late WorkspaceSources sources;

    setUp(() {
      sources = WorkspaceSources.locate();
    });

    test('nothing aggregates, rounds or re-ranks in the app', () {
      // No carve-out here on purpose: nothing under app/lib has a reason to
      // reach for one of these, and a component that does is the defect this
      // rule exists to catch before five more components are built on it.
      expect(sources.offenders('app/lib', computationMechanisms), isEmpty);
    });

    test('nothing aggregates, rounds or re-ranks in the packages', () {
      expect(
        sources.offenders(
          'packages',
          computationMechanisms,
          allow: computationAllowed,
        ),
        isEmpty,
      );
    });

    test('every carve-out still names a file that exists', () {
      // An allowance that outlives the file it excused is a hole nobody can
      // see. This fails when one is renamed or deleted without being removed.
      final present = <String>{...sources.under('packages').keys};
      expect(computationAllowed.difference(present), isEmpty);
    });
  });
}
