import 'dart:io';

/// Reads the workspace's Dart sources so the architecture tests can assert
/// over them.
///
/// The layering tests parse text rather than the analyzed element model on
/// purpose: the checks must stay cheap enough to run in every `flutter test`,
/// and an import is a line of text. The cost is that they see the source, not
/// the semantics — which is why each rule targets a mechanism (an import, a
/// constructor call) rather than an intent.
class WorkspaceSources {
  /// Locates the workspace by walking up from the current directory.
  ///
  /// `flutter test` runs with the package as its working directory and
  /// `dart test` may not, so neither a relative path nor `Platform.script`
  /// is reliable; the marker is the workspace root's own pubspec.
  factory WorkspaceSources.locate() {
    var directory = Directory.current.absolute;
    while (true) {
      final pubspec = File('${directory.path}/pubspec.yaml');
      if (pubspec.existsSync() &&
          pubspec.readAsStringSync().contains('\nworkspace:')) {
        return WorkspaceSources._(directory);
      }
      final parent = directory.parent;
      if (parent.path == directory.path) {
        throw StateError('no pub workspace root above ${Directory.current}');
      }
      directory = parent;
    }
  }

  WorkspaceSources._(this.root);

  /// The `frontend/` directory.
  final Directory root;

  /// Every `.dart` file under [relative], as (path relative to [root], text).
  ///
  /// Build output and resolved dependencies are excluded — they are not this
  /// repository's code and their contents would fail every rule here.
  Map<String, String> under(String relative) {
    final directory = Directory('${root.path}/$relative');
    if (!directory.existsSync()) {
      throw StateError('no such directory: $relative');
    }
    final sources = <String, String>{};
    for (final file in directory.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final path = file.path.substring(root.path.length + 1);
      if (path.contains('/.dart_tool/') || path.contains('/build/')) continue;
      sources[path] = file.readAsStringSync();
    }
    if (sources.isEmpty) throw StateError('no sources under $relative');
    return sources;
  }

  /// Paths under [relative] whose text contains any of [needles].
  ///
  /// Returned as `path: needle` so a failure names both the file and the rule
  /// it broke, instead of just asserting `isEmpty`.
  Map<String, String> offenders(
    String relative,
    List<String> needles, {
    Set<String> allow = const <String>{},
  }) {
    final found = <String, String>{};
    under(relative).forEach((path, text) {
      if (allow.contains(path)) return;
      for (final needle in needles) {
        if (text.contains(needle)) {
          found[path] = needle;
          return;
        }
      }
    });
    return found;
  }
}
