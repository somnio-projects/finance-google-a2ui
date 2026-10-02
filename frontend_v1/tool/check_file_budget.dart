// Fails when any Dart file exceeds the line budget.
//
// The Dart counterpart of backend/scripts/check_file_budget.py, and the same
// argument: a file that needs more than `maxLines` lines is doing more than
// one thing. Splitting it by responsibility is the fix; "part 1 / part 2" is
// not.
//
// Usage: dart run tool/check_file_budget.dart [roots...]
import 'dart:io';

/// The budget, identical to the backend's.
const int maxLines = 150;

/// Where sources live when no root is given on the command line.
///
/// `test/` is the workspace root's own suite — the one that covers `tool/`.
/// It was missing here while `tool/` was present, so the scripts the gate is
/// made of were budgeted and their tests were not.
const List<String> defaultRoots = <String>['app', 'packages', 'test', 'tool'];

/// Directories that never count: build output and resolved dependencies.
const List<String> skippedSegments = <String>[
  '/.dart_tool/',
  '/build/',
  '/coverage/',
];

void main(List<String> args) {
  final roots = args.isEmpty ? defaultRoots : args;
  final offenders = <({String path, int lines})>[];
  var scanned = 0;
  for (final root in roots) {
    final directory = Directory(root);
    if (!directory.existsSync()) continue;
    for (final file in directory.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      if (skippedSegments.any(file.path.contains)) continue;
      scanned++;
      final lines = file.readAsLinesSync().length;
      if (lines > maxLines) {
        offenders.add((path: file.path, lines: lines));
      }
    }
  }
  if (offenders.isEmpty) {
    stdout.writeln('file budget ok ($maxLines lines, $scanned files)');
    return;
  }
  offenders.sort((a, b) => b.lines.compareTo(a.lines));
  for (final offender in offenders) {
    stdout.writeln(
      '${offender.path}: ${offender.lines} lines (budget $maxLines)',
    );
  }
  stdout.writeln('${offenders.length} file(s) over budget — split them.');
  exit(1);
}
