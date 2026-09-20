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
// Usage: dart run tool/check_coverage.dart <file.info> [more.info ...]
import 'dart:io';

/// The minimum line coverage every counted file must reach.
const double threshold = 100;

/// Files exempt from the threshold, each for a reason worth naming:
///
///  * generated code (`*.g.dart`, `*.freezed.dart`) is the build's output,
///    not hand-written logic — the rule's own exemption;
///  * `lib/main.dart` is `runApp(bootstrap())` and nothing else. Executing it
///    in a test starts the real app, which opens a socket to the configured
///    backend; everything worth asserting lives in `bootstrap.dart`, which is
///    at 100 %.
bool isExempt(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('/lib/main.dart');

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/check_coverage.dart <lcov.info...>');
    exit(2);
  }
  final records = <String, ({int found, int hit})>{};
  for (final arg in args) {
    final file = File(arg);
    if (!file.existsSync()) {
      stderr.writeln('coverage report not found: $arg');
      exit(2);
    }
    _read(file, into: records);
  }
  if (records.isEmpty) {
    stderr.writeln('no coverage records found — did the suite run?');
    exit(1);
  }
  final failures = <String>[];
  for (final entry in records.entries) {
    if (isExempt(entry.key)) continue;
    final found = entry.value.found;
    final percent = found == 0 ? 100.0 : entry.value.hit * 100 / found;
    if (percent < threshold) {
      failures.add(
        '${entry.key}: ${percent.toStringAsFixed(1)} % '
        '(${entry.value.hit}/$found lines)',
      );
    }
  }
  if (failures.isEmpty) {
    stdout.writeln(
      'coverage ok — ${records.length} file(s) at or above '
      '${threshold.toStringAsFixed(0)} %',
    );
    return;
  }
  failures.sort();
  final summary =
      '${failures.length} file(s) below '
      '${threshold.toStringAsFixed(0)} % line coverage.';
  stdout.writeln(<String>[...failures, summary].join('\n'));
  exit(1);
}

void _read(File file, {required Map<String, ({int found, int hit})> into}) {
  String? current;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3);
      into.putIfAbsent(current, () => (found: 0, hit: 0));
    } else if (line.startsWith('LF:') && current != null) {
      final previous = into[current]!;
      into[current] = (
        found: previous.found + int.parse(line.substring(3)),
        hit: previous.hit,
      );
    } else if (line.startsWith('LH:') && current != null) {
      final previous = into[current]!;
      into[current] = (
        found: previous.found,
        hit: previous.hit + int.parse(line.substring(3)),
      );
    }
  }
}
