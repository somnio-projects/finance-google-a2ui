// Where a colour literal may be written, checked against the source.
//
// `frontend/CLAUDE.md` says: *"Colour literals live in a `*_tokens.dart` and
// nowhere else."* Four files in `app/lib/` went further and each claimed to be
// **the** one — `chart_tokens.dart`, `chart_palette.dart`,
// `allocation_palette.dart` and `payoff_tokens.dart` — and all four sentences
// were false. Twelve files named a `Color` when this test was written, five of
// them widgets (GGU-105 §2).
//
// The claim did not rot through carelessness. ADR-L D-3 forbids editing a
// shared file to add a component, so every new design-bound surface correctly
// wrote its **own** token file, and two agents reached that answer in the same
// week without conferring. The seam was working; the sentence describing it was
// not, and GGU-105's point is that replacing one unenforced sentence with
// another resets the clock rather than stopping it.
//
// So the rule is a **naming convention**, not a path list. A path list would
// have to be edited every time a component is added, which is precisely what
// ADR-L D-3 forbids — the check would be the seam violation it is meant to
// protect. `<anything>_tokens.dart` and `<anything>_palettes.dart` may name a
// colour; nothing else may, and [colourHomes] has no exceptions at all.
//
// Mutation-checked, both ways (spec frontend/0029 AC-4): adding
// `Color(0xFF00FF00)` to `holdings_view.dart` fails the first test and names
// the file; emptying `colourHomes` fails the second on its length.
import 'package:flutter_test/flutter_test.dart';

import 'workspace_sources.dart';

/// The filename suffixes a colour literal may appear in.
///
/// Two, and the *size* is asserted — the idiom `speech_rules_test.dart` uses
/// for the browser seam. A third suffix is a decision worth making on purpose,
/// because each one is a place a measured design value can hide.
const Set<String> colourHomes = <String>{'_tokens.dart', '_palettes.dart'};

/// Every way this codebase can spell a colour literal.
///
/// `Color(0x…)` is the form the design values are transcribed in; the three
/// factories are the equivalent forms a reader reaching for a hex value might
/// use instead. Asserting only the first would leave the rule satisfiable by a
/// synonym, which is how `repo.spelling` once passed while scanning nothing.
const List<String> colourLiterals = <String>[
  'Color(0x',
  'Color.fromARGB(',
  'Color.fromRGBO(',
  'Color.from(',
];

/// Paths that may name a colour although their name does not end in a
/// [colourHomes] suffix.
///
/// **Empty, and asserted empty.** Five widget files and `theme/app_colors.dart`
/// were outside the convention when this test was written; the widgets' values
/// moved onto `HoldingsTokens` and `LoginTokens` as `static const`s (the shape
/// `LoginTokens.logoGradient` already had) and `app_colors.dart` was renamed
/// `app_color_tokens.dart`. An allow-list was the cheaper alternative and was
/// rejected: the only reason any of those six qualified was that nobody had
/// moved them, and "it was here first" is the justification this repository
/// keeps finding at the bottom of a rotted rule.
const Set<String> colourHomeExceptions = <String>{};

/// The smallest number of colour-naming files this app can plausibly have.
///
/// Every assertion below is universally quantified over the files the walk
/// found, so an empty or tiny walk satisfies all of them — the vacuity failure
/// `check_coverage.dart` and `repo.spelling` each shipped with. There were
/// twenty-one on 2026-09-24.
const int minimumColourFiles = 15;

void main() {
  group('the colour rule (spec frontend/0029)', () {
    late WorkspaceSources sources;

    setUp(() {
      sources = WorkspaceSources.locate();
    });

    /// Files under [relative] that name a colour, keyed by the form they used.
    Map<String, String> colourFiles(String relative) =>
        sources.offenders(relative, colourLiterals);

    test('only a *_tokens.dart or *_palettes.dart names a Color', () {
      final offenders = colourFiles('app/lib')
        ..removeWhere(
          (path, _) =>
              colourHomeExceptions.contains(path) ||
              colourHomes.any(path.endsWith),
        );
      expect(offenders, isEmpty);
    });

    test('the rule reaches enough files to mean anything', () {
      // Not "the walk found files" — `under()` already throws on that — but
      // "the walk found the *colour* files". A refactor that moved every
      // palette out of `app/lib/` would leave the test above green and this
      // one red, which is the correct way round.
      expect(
        colourFiles('app/lib'),
        hasLength(greaterThanOrEqualTo(minimumColourFiles)),
      );
      // And the hole's size, like the browser seam's: two suffixes, no paths.
      expect(colourHomes, hasLength(2));
      expect(colourHomeExceptions, isEmpty);
    });

    test('a pure-Dart package names no Color at all', () {
      // `packages/` cannot import Flutter (layering_test.dart), so a `Color`
      // there could only come from `dart:ui` — which that test also forbids.
      // This says the same thing from the other end: the geometry packages
      // compute coordinates, and a colour is a decision for the paint layer.
      expect(sources.offenders('packages', colourLiterals), isEmpty);
    });
  });
}
