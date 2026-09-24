// Reading lcov reports, split out of check_coverage.dart to keep both inside
// the 150-line budget the gate enforces on itself.
import 'dart:io';

/// Line counts for one source file, summed across every report that named it.
typedef LcovCounts = ({int found, int hit});

/// Parses every `SF:`/`LF:`/`LH:` triple in [reports`.
///
/// Returns the raw `SF:` path as the key — [coverageKey] normalises it.
/// Exits the process when a named report is missing, because a gate that
/// silently skips an absent report proves nothing.
Map<String, LcovCounts> readLcov(List<String> reports) {
  final records = <String, LcovCounts>{};
  for (final report in reports) {
    final file = File(report);
    if (!file.existsSync()) {
      stderr.writeln('coverage report not found: $report');
      exit(2);
    }
    _read(file, into: records);
  }
  return records;
}

/// Normalises an lcov `SF:` path to a `<package dir>/lib/<path>` key.
///
/// `flutter test` writes package-relative paths (`lib/x.dart`); the
/// `dart test` + `format_coverage` pair writes absolute ones. Both have to
/// line up with the paths a directory walk produces.
String coverageKey(String sf) {
  final packages = sf.indexOf('/packages/');
  if (packages >= 0) return sf.substring(packages + 1);
  if (sf.startsWith('lib/')) return 'app/$sf';
  final app = sf.indexOf('/app/lib/');
  if (app >= 0) return sf.substring(app + 1);
  return sf;
}

void _read(File file, {required Map<String, LcovCounts> into}) {
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
