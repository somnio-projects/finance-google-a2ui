import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'workspace_sources.dart';

void main() {
  group('component manifest', () {
    late WorkspaceSources sources;

    setUp(() {
      sources = WorkspaceSources.locate();
    });

    test('lists exactly the component directories that exist', () {
      // The gate also re-renders and diffs the file
      // (`make manifest-check`); this asserts the same invariant inside the
      // suite, so a developer who adds a directory and forgets to regenerate
      // sees it on the first `flutter test` rather than at the end of CI.
      final directories =
          Directory('${sources.root.path}/app/lib/components')
              .listSync()
              .whereType<Directory>()
              .map((d) => d.path.split('/').last)
              .toList()
            ..sort();
      final manifest = File(
        '${sources.root.path}/app/lib/components/component_manifest.g.dart',
      ).readAsStringSync();

      expect(directories, isNotEmpty);
      for (final name in directories) {
        expect(
          manifest,
          contains('$name.register(registry);'),
          reason: '$name is not wired into the generated manifest',
        );
      }
      expect(
        'register(registry);'.allMatches(manifest).length,
        equals(directories.length),
        reason: 'the manifest registers something that has no directory',
      );
    });

    test('says it is generated and how to regenerate it', () {
      final manifest = File(
        '${sources.root.path}/app/lib/components/component_manifest.g.dart',
      ).readAsStringSync();
      expect(manifest, contains('GENERATED FILE'));
      expect(manifest, contains('generate_component_manifest.dart'));
    });
  });
}
