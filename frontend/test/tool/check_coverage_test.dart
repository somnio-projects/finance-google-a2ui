import 'dart:io';

import 'package:test/test.dart';

import '../../tool/coverage_sources.dart';
import 'tool_harness.dart';

void main() {
  group('isExempt', () {
    test('exempts generated code and the runApp entry point', () {
      expect(isExempt('app/lib/components/component_manifest.g.dart'), isTrue);
      expect(isExempt('app/lib/x.freezed.dart'), isTrue);
      expect(isExempt('app/lib/main.dart'), isTrue);
    });

    test('exempts nothing else', () {
      expect(isExempt('app/lib/bootstrap.dart'), isFalse);
      expect(
        isExempt('packages/finance_charts/lib/src/band_scale.dart'),
        isFalse,
      );
      // A file that merely *contains* the word is not generated.
      expect(isExempt('app/lib/g.dart'), isFalse);
    });
  });

  group('hasExecutableCode', () {
    late Directory dir;

    setUp(() => dir = makeTempDir());
    tearDown(() => dir.deleteSync(recursive: true));

    test('sees nothing to run in a barrel', () {
      // lcov correctly writes no record for a file of `export` directives,
      // so the must-have-a-record rule has to know the difference.
      expect(
        hasExecutableCode(
          writeFile(dir, 'barrel.dart', '''
// A comment.
library;

import 'dart:io';
export 'src/a.dart';
part 'b.dart';
'''),
        ),
        isFalse,
      );
    });

    test('sees a declaration as something to run', () {
      expect(
        hasExecutableCode(
          writeFile(dir, 'real.dart', "import 'dart:io';\nconst int x = 1;\n"),
        ),
        isTrue,
      );
    });

    test('sees nothing in an empty file', () {
      expect(hasExecutableCode(writeFile(dir, 'empty.dart', '')), isFalse);
    });
  });

  group('libSources', () {
    late Directory dir;

    setUp(() => dir = makeTempDir());
    tearDown(() => dir.deleteSync(recursive: true));

    test('walks app/lib and every package lib', () {
      writeFile(dir, 'app/lib/a.dart', 'const int a = 1;');
      writeFile(dir, 'packages/p/lib/b.dart', 'const int b = 1;');
      writeFile(dir, 'packages/p/lib/src/c.dart', 'const int c = 1;');
      writeFile(dir, 'packages/p/test/d_test.dart', 'const int d = 1;');
      writeFile(dir, 'app/lib/notes.md', 'not dart');
      final found = libSources(from: dir.path).keys
          .map((path) => path.substring(dir.path.length + 1))
          .toSet();
      expect(found, <String>{
        'app/lib/a.dart',
        'packages/p/lib/b.dart',
        'packages/p/lib/src/c.dart',
      });
    });

    test('returns nothing when there is nothing to walk', () {
      // The empty walk itself. `main` turns this into an exit code; the
      // point here is that it is *observable* rather than indistinguishable
      // from a clean run.
      expect(libSources(from: dir.path), isEmpty);
    });

    test('tolerates a package directory with no lib', () {
      writeFile(dir, 'app/lib/a.dart', 'const int a = 1;');
      Directory('${dir.path}/packages/empty').createSync(recursive: true);
      expect(libSources(from: dir.path), hasLength(1));
    });
  });
}
