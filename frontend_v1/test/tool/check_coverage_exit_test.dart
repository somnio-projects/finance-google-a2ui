import 'dart:io';

import 'package:test/test.dart';

import 'tool_harness.dart';

/// The gate's exit codes, proved by running it.
///
/// `libSources` being empty is the *precondition*; the thing that matters is
/// that the process then **fails**. That is the whole defect: the script used
/// to print `coverage ok — 0 lib file(s) accounted for` and exit 0 when its
/// walk found nothing, so the gate was green precisely when it was checking
/// nothing. Asserting the helper returns an empty map would not have caught
/// it — only the exit code does, which is why this suite spawns the script.
///
/// `tool/` is outside the coverage contract (it is not `lib/`), so without
/// this the one behaviour the tool suite exists to protect would have no
/// automated test at all.
void main() {
  final script = '${Directory.current.path}/tool/check_coverage.dart';

  /// Runs the gate in [cwd] with [args] and returns its exit code and stderr.
  Future<({int code, String err})> run(String cwd, List<String> args) async {
    final result = await Process.run('dart', <String>[
      script,
      ...args,
    ], workingDirectory: cwd);
    return (code: result.exitCode, err: result.stderr.toString());
  }

  group('check_coverage exit codes', () {
    late Directory dir;

    setUp(() => dir = makeTempDir());
    tearDown(() => dir.deleteSync(recursive: true));

    test('fails when the walk finds no lib/ sources', () async {
      writeFile(dir, 'lcov.info', 'SF:lib/a.dart\nLF:2\nLH:2\n');
      final result = await run(dir.path, <String>['lcov.info']);
      expect(result.code, 2, reason: 'a vacuous pass is the defect');
      expect(result.err, contains('no lib/ sources found'));
    });

    test('fails when no report names any file', () async {
      writeFile(dir, 'app/lib/a.dart', 'const int a = 1;');
      writeFile(dir, 'empty.info', '');
      final result = await run(dir.path, <String>['empty.info']);
      expect(result.code, 1);
      expect(result.err, contains('no coverage records found'));
    });

    test('fails when a named report does not exist', () async {
      final result = await run(dir.path, <String>['missing.info']);
      expect(result.code, 2);
      expect(result.err, contains('coverage report not found'));
    });

    test('fails when given no report at all', () async {
      final result = await run(dir.path, const <String>[]);
      expect(result.code, 2);
      expect(result.err, contains('usage:'));
    });

    test('passes on a tree whose every file has a full record', () async {
      // The positive case, so the suite is not only proving red paths: a
      // check that can only fail proves as little as one that can only pass.
      writeFile(dir, 'app/lib/a.dart', 'const int a = 1;');
      writeFile(
        dir,
        'lcov.info',
        'SF:${dir.path}/app/lib/a.dart\nLF:1\nLH:1\n',
      );
      final result = await run(dir.path, <String>['lcov.info']);
      expect(result.code, 0, reason: result.err);
    });
  });
}
