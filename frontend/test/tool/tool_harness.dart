import 'dart:io';

/// A scratch directory for a test that needs a file tree.
///
/// The gate's scripts walk directories and read files, so testing them means
/// giving them a tree. Building one per test keeps the suites independent and
/// keeps them out of the repository they are checking.
Directory makeTempDir() =>
    Directory.systemTemp.createTempSync('frontend-tool-test');

/// Writes [contents] to `<dir>/<relative>`, creating parents, and returns it.
File writeFile(Directory dir, String relative, String contents) {
  final file = File('${dir.path}/$relative');
  file.parent.createSync(recursive: true);
  return file..writeAsStringSync(contents);
}
