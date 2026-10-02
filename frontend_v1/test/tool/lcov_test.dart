import 'dart:io';

import 'package:test/test.dart';

import '../../tool/lcov.dart';
import 'tool_harness.dart';

void main() {
  group('coverageKey', () {
    test('normalises an absolute package path', () {
      expect(
        coverageKey('/x/frontend/packages/finance_charts/lib/src/a.dart'),
        'packages/finance_charts/lib/src/a.dart',
      );
    });

    test('normalises the package-relative path flutter test writes', () {
      expect(coverageKey('lib/bootstrap.dart'), 'app/lib/bootstrap.dart');
    });

    test('normalises an absolute app path', () {
      expect(
        coverageKey('/x/frontend/app/lib/bootstrap.dart'),
        'app/lib/bootstrap.dart',
      );
    });

    test('leaves a path it does not recognise alone', () {
      // Better an unmatched key — which shows up as a missing record — than
      // a silently rewritten one that lines up with the wrong file.
      expect(coverageKey('somewhere/else.dart'), 'somewhere/else.dart');
    });
  });

  group('readLcov', () {
    late Directory dir;

    setUp(() => dir = makeTempDir());
    tearDown(() => dir.deleteSync(recursive: true));

    test('sums the line counts of every record', () {
      final report = writeFile(dir, 'lcov.info', '''
SF:lib/a.dart
DA:1,1
LF:10
LH:9
end_of_record
SF:lib/b.dart
LF:4
LH:4
end_of_record
''');
      final records = readLcov(<String>[report.path]);
      expect(records, hasLength(2));
      expect(records['lib/a.dart'], (found: 10, hit: 9));
      expect(records['lib/b.dart'], (found: 4, hit: 4));
    });

    test('adds up a file that two reports both name', () {
      // The four suites write four reports and can overlap; a file counted
      // once per report would look worse covered than it is.
      final a = writeFile(dir, 'a.info', 'SF:lib/x.dart\nLF:6\nLH:3\n');
      final b = writeFile(dir, 'b.info', 'SF:lib/x.dart\nLF:6\nLH:3\n');
      expect(readLcov(<String>[a.path, b.path])['lib/x.dart'], (
        found: 12,
        hit: 6,
      ));
    });

    test('ignores counts that arrive before any file', () {
      final report = writeFile(
        dir,
        'stray.info',
        'LF:5\nLH:5\nSF:lib/y.dart\n',
      );
      expect(readLcov(<String>[report.path]), hasLength(1));
      expect(readLcov(<String>[report.path])['lib/y.dart'], (found: 0, hit: 0));
    });
  });
}
