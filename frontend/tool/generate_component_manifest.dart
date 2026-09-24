// Renders app/lib/components/component_manifest.g.dart from the component
// directories that exist on disk.
//
// This is the seam that makes ADR-L D-3 true. Dart has no runtime reflection
// on the web, so a library whose top level nothing imports is tree-shaken away
// and its registration never runs — a component therefore *has* to be imported
// somewhere. Generating that one file, instead of hand-editing it, is what
// keeps "adding a component edits no existing file" honest.
//
// The generated file is checked in *and* re-rendered by the gate and diffed,
// which is the repository's standing rule for generated artefacts
// (`.claude/rules/ci-conventions.md` §4) and the same shape as the backend's
// `generate_catalog_contract.py`.
//
// Usage:
//   dart run tool/generate_component_manifest.dart            # write
//   dart run tool/generate_component_manifest.dart --check    # verify
import 'dart:io';

const String _componentsDir = 'app/lib/components';
const String _manifestPath = '$_componentsDir/component_manifest.g.dart';
const String _regenerate =
    'cd frontend && dart run tool/generate_component_manifest.dart';

void main(List<String> args) {
  final check = args.contains('--check');
  final modules = _discover();
  if (modules.isEmpty) {
    stderr.writeln('no component modules found under $_componentsDir');
    exit(1);
  }
  final rendered = _render(modules);
  final manifest = File(_manifestPath);
  final current = manifest.existsSync() ? manifest.readAsStringSync() : '';
  if (!check) {
    manifest.writeAsStringSync(rendered);
    stdout.writeln('wrote $_manifestPath (${modules.length} component(s))');
    return;
  }
  if (current == rendered) {
    stdout.writeln('component manifest is current (${modules.length})');
    return;
  }
  stderr
    ..writeln('$_manifestPath is stale.')
    ..writeln('Regenerate it and commit the result:')
    ..writeln('  $_regenerate');
  exit(1);
}

/// One component module: its directory name and the file that exposes
/// `register`.
typedef _Module = ({String name, String file});

List<_Module> _discover() {
  final root = Directory(_componentsDir);
  if (!root.existsSync()) return const <_Module>[];
  final modules = <_Module>[];
  for (final entry in root.listSync().whereType<Directory>()) {
    final name = entry.uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .last;
    final file = File('${entry.path}/${name}_component.dart');
    if (!file.existsSync()) {
      stderr.writeln(
        'component directory "$name" has no ${name}_component.dart — '
        'every component module is named after its directory',
      );
      exit(1);
    }
    modules.add((name: name, file: '$name/${name}_component.dart'));
  }
  // Sorted so the file is a function of the directory set alone: two people
  // adding a component on two branches get a one-line, conflict-free diff.
  modules.sort((a, b) => a.name.compareTo(b.name));
  return modules;
}

String _render(List<_Module> modules) {
  final imports = modules
      .map(
        (m) =>
            "import 'package:finance_app/components/${m.file}'\n"
            '    as ${m.name};',
      )
      .join('\n');
  final calls = modules
      .map((m) => '  ${m.name}.register(registry);')
      .join('\n');
  return '''
// GENERATED FILE — do not edit by hand.
// Regenerate with: $_regenerate
//
// One entry per directory under $_componentsDir. Adding a component means
// adding its directory and running the command above; no hand-written file
// changes (ADR-L D-3). `make manifest-check` fails the gate when this file
// and the directories disagree.

import 'package:finance_app/components/component_registry.dart';
$imports

/// Registers every catalog component this build ships.
void registerCatalogComponents(ComponentRegistry registry) {
$calls
}
''';
}
