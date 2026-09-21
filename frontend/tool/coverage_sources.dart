// Which files the coverage contract counts, and which it excuses.
//
// Split out of `check_coverage.dart` to keep both inside the 150-line budget
// the gate enforces on itself — and the seam is a real one: this file answers
// "what should have a record", `check_coverage.dart` answers "does it".
import 'dart:io';

import 'lcov.dart';

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
///
/// [from] lets `test/tool/` point the walk at a fixture tree.
Map<String, File> libSources({String from = '.'}) {
  final prefix = from == '.' ? '' : '$from/';
  final roots = <Directory>[Directory('${prefix}app/lib')];
  final packages = Directory('${prefix}packages');
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
