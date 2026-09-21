// Enforces the coverage contract over one or more lcov files.
//
// Why a script rather than a flag: `flutter test --coverage` reports a number
// and exits 0 whatever it is, and an overall percentage hides a file at 0 %
// behind nine at 100 %. This checks **per file**, which is the bar
// `.claude/rules/flutter/testing.md` sets and the one the backend's 100 %
// branch gate means.
//
// Dart's coverage tooling emits **line** hits only — there is no branch data
// in lcov for Dart — so the backend's "100 % branch" cannot be reproduced
// literally. 100 % line coverage per file is the strongest honest equivalent.
// The threshold goes up, never down, and never in a feature PR.
//
// **It also fails on a file with no record at all**, which is the half that is
// easy to get wrong. lcov writes nothing for a library no test imported, so
// checking only the records would have meant "100 % of the files the tests
// happened to load" — a new untested file would have passed silently. The file
// list therefore comes from disk and the records are checked against it.
//
// Usage: dart run tool/check_coverage.dart <file.info> [more.info ...]
import 'dart:io';

import 'lcov.dart';

/// The minimum line coverage every counted file must reach.
const double threshold = 100;

/// Files exempt from the threshold and from the must-have-a-record rule.
///
///  * generated code (`*.g.dart`, `*.freezed.dart`) is the build's output,
///    not hand-written logic — the rule's own exemption;
///  * `lib/main.dart` is `runApp(bootstrap())` and nothing else. Executing it
///    in a test starts the real app, which builds a real `http.Client` and
///    opens a socket to the configured backend; everything worth asserting
///    lives in `bootstrap.dart`, which is at 100 %.
///
/// **Always call this on a [coverageKey], never on a raw `SF:` path.**
/// `flutter test` writes package-relative records (`lib/main.dart`), which do
/// not end with `/lib/main.dart`, so the exemption silently missed them while
/// the failure message printed the normalised name — a path that *looks*
/// exempt. The disk side happened to pass `app/lib/main.dart` and worked,
/// which is why the records side stayed dead and unnoticed.
bool isExempt(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('/lib/main.dart');

/// Whether [file] contains anything that could be executed.
///
/// A barrel of `export` directives has no executable line, so lcov correctly
/// writes no record for it. Deciding that by parsing — rather than listing the
/// barrels — keeps the rule working when someone adds a fifth package, while
/// still failing on a real file nobody tested.
bool hasExecutableCode(File file) {
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('//')) continue;
    if (line.startsWith('import ') || line.startsWith('export ')) continue;
    if (line == 'library;' || line.startsWith('library ')) continue;
    if (line.startsWith('part ')) continue;
    return true;
  }
  return false;
}

/// Every `lib/` source in the workspace, keyed by its path from `frontend/`.
Map<String, File> libSources() {
  final roots = <Directory>[Directory('app/lib')];
  final packages = Directory('packages');
  if (packages.existsSync()) {
    for (final entry in packages.listSync().whereType<Directory>()) {
      roots.add(Directory('${entry.path}/lib'));
    }
  }
  final sources = <String, File>{};
  for (final root in roots) {
    if (!root.existsSync()) continue;
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (file.path.endsWith('.dart')) sources[file.path] = file;
    }
  }
  return sources;
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/check_coverage.dart <lcov.info...>');
    exit(2);
  }
  final records = readLcov(args);
  if (records.isEmpty) {
    stderr.writeln('no coverage records found — did the suite run?');
    exit(1);
  }

  final sources = libSources();
  if (sources.isEmpty) {
    // The disk walk is the half that catches a file no test ever loaded. An
    // empty walk cannot catch anything, so reporting "ok — 0 files accounted
    // for" would be this gate reproducing the exact lcov blindness it was
    // written to fix. `workspace_sources.dart` throws in the same situation;
    // this script used to exit 0.
    stderr.writeln(
      'no lib/ sources found under app/ or packages/ — the disk cross-check '
      'would pass vacuously. Run this from the frontend/ directory.',
    );
    exit(2);
  }
  final covered = records.keys.map(coverageKey).toSet();
  final failures = <String>[
    ...sources.entries
        .where(
          (entry) =>
              !isExempt(entry.key) &&
              !covered.contains(entry.key) &&
              hasExecutableCode(entry.value),
        )
        .map((entry) => '${entry.key}: no coverage record — no test loads it'),
    // Normalised before the exemption is tested: the raw `SF:` path is the
    // one spelling `isExempt` cannot read (see its doc comment).
    ...records.entries
        .where((entry) => !isExempt(coverageKey(entry.key)))
        .map(_shortfall),
  ]..removeWhere((failure) => failure.isEmpty);

  if (failures.isEmpty) {
    stdout.writeln(
      'coverage ok — ${sources.length} lib file(s) accounted for, '
      '${records.length} at or above ${threshold.toStringAsFixed(0)} %',
    );
    return;
  }
  failures.sort();
  final summary =
      '${failures.length} coverage failure(s); the contract is '
      '${threshold.toStringAsFixed(0)} % line coverage per file.';
  stdout.writeln(<String>[...failures, summary].join('\n'));
  exit(1);
}

/// Describes [entry]'s shortfall, or the empty string when it meets the bar.
String _shortfall(MapEntry<String, LcovCounts> entry) {
  final found = entry.value.found;
  final percent = found == 0 ? 100.0 : entry.value.hit * 100 / found;
  if (percent >= threshold) return '';
  return '${coverageKey(entry.key)}: ${percent.toStringAsFixed(1)} % '
      '(${entry.value.hit}/$found lines)';
}
