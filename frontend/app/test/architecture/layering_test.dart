// The layering rules, checked against the source rather than remembered.
//
// The backend has `tests/unit/presentation/test_package_boundaries.py`; this
// is its counterpart, and it exists for the same reason: a rule a human has to
// remember is not a rule. Each test below fails on a *mechanism*, so a
// forbidden import or a stray constructor turns the suite red immediately.
//
// Mutation-checked: adding `import 'package:flutter/material.dart';` to a file
// under `packages/` and `NumberFormat` to a component both make this file
// fail. If you change a rule here, re-run that check.
import 'package:flutter_test/flutter_test.dart';

import 'workspace_sources.dart';

void main() {
  group('layering', () {
    late WorkspaceSources sources;

    setUp(() {
      sources = WorkspaceSources.locate();
    });

    test('no package under packages/ imports Flutter', () {
      // These three packages are pure Dart. Keeping them so is what lets the
      // domain be tested with `dart test`, and it is a compile error rather
      // than a convention — this test only names the rule.
      expect(
        sources.offenders('packages', <String>[
          "import 'package:flutter/",
          "import 'dart:ui'",
        ]),
        isEmpty,
      );
    });

    test('finance_core depends on nothing above it', () {
      expect(
        sources.offenders('packages/finance_core/lib', <String>[
          'package:finance_api_client/',
          'package:finance_views_repository/',
          'package:http/',
        ]),
        isEmpty,
      );
    });

    test('the data layer never reaches up into the repository layer', () {
      expect(
        sources.offenders('packages/finance_api_client/lib', <String>[
          'package:finance_views_repository/',
        ]),
        isEmpty,
      );
    });

    test('blocs talk to repositories, never to the transport', () {
      expect(
        sources.offenders('app/lib/features', <String>[
          'package:finance_api_client/',
          'package:http/',
        ]),
        isEmpty,
      );
    });

    test('components never import a feature or the transport', () {
      // A component binds a payload. If it needs a bloc it is a feature, and
      // it belongs under `features/` instead.
      expect(
        sources.offenders('app/lib/components', <String>[
          'package:finance_app/features/',
          'package:finance_api_client/',
        ]),
        isEmpty,
      );
    });

    test('only bootstrap.dart constructs infrastructure', () {
      // The single composition root (ADR-L D-2), the analogue of the
      // backend's bootstrap.py.
      expect(
        sources.offenders(
          'app/lib',
          <String>['http.Client(', 'FinanceApiClient(', 'ViewsRepository('],
          allow: <String>{'app/lib/bootstrap.dart'},
        ),
        isEmpty,
      );
    });

    test('nothing formats or computes a number', () {
      // Prohibitions N-1 and N-2, as a mechanism check. Every figure the user
      // sees is a `*Display` string the backend produced; a client that can
      // reach for `NumberFormat` eventually does.
      expect(
        sources.offenders('app/lib', <String>[
          'NumberFormat',
          'package:intl/',
          "import 'dart:math'",
          'toStringAsFixed',
          'double.parse',
          'num.parse',
        ]),
        isEmpty,
      );
      expect(
        sources.offenders('packages', <String>[
          'NumberFormat',
          'package:intl/',
          "import 'dart:math'",
          'toStringAsFixed',
          'double.parse',
        ]),
        isEmpty,
      );
    });

    test('nothing reads the device clock', () {
      // N-13: `as_of` is the backend's, and it travels in the envelope.
      expect(sources.offenders('app/lib', <String>['DateTime.now(']), isEmpty);
      expect(sources.offenders('packages', <String>['DateTime.now(']), isEmpty);
    });

    test('every component module registers exactly one component', () {
      // A component module lives in its own directory and is named after
      // it; `components/view_component.dart` is the abstraction, not a
      // module, and must not be swept up by the glob.
      final modules = sources.under('app/lib/components')
        ..removeWhere(
          (path, _) =>
              !RegExp(r'components/([a-z_]+)/\1_component\.dart$')
                  .hasMatch(path),
        );
      expect(modules, isNotEmpty);
      for (final entry in modules.entries) {
        expect(
          'void register('.allMatches(entry.value).length,
          equals(1),
          reason: '${entry.key} must expose exactly one register()',
        );
      }
    });
  });
}
