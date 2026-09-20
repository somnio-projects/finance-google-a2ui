// The layer boundaries and the composition root, checked against the source.
//
// The backend has `tests/unit/presentation/test_package_boundaries.py`; this is
// its counterpart, and it exists for the same reason: a rule a human has to
// remember is not a rule. Each test fails on a *mechanism*, so a forbidden
// import or a stray constructor turns the suite red immediately.
//
// The contract-binding mechanisms — no formatting, no arithmetic, no clock, no
// interpreted templates — are in `binding_rules_test.dart`.
//
// Mutation-checked: adding `import 'package:flutter/material.dart';` to a file
// under `packages/` makes this file fail. If you change a rule here, mutate it
// and watch it go red.
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

    test('only a page resolves a repository from the widget tree', () {
      // The page/view split from `.claude/rules/flutter/architecture.md`: a
      // *page* owns its bloc's lifetime and may read the repository the bloc
      // needs; a *view* reads bloc state and nothing else. Without this rule
      // `context.read<ViewsRepository>()` could drift into any widget, which
      // is the thing the split exists to prevent.
      final offenders = sources.offenders('app/lib', <String>[
        'context.read<ViewsRepository>',
        'context.watch<ViewsRepository>',
      ]);
      expect(
        offenders.keys.where((path) => !path.endsWith('_page.dart')),
        isEmpty,
      );
    });

    test('components never import a feature or the transport', () {
      // A component binds a payload. It may import the repository package for
      // `ViewPayload` — a type — but never reads a repository instance, which
      // the rule above enforces.
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

    test('only AppConfig reads the build environment', () {
      expect(
        sources.offenders(
          'app/lib',
          <String>['String.fromEnvironment', 'Platform.environment'],
          allow: <String>{'app/lib/app/app_config.dart'},
        ),
        isEmpty,
      );
    });
  });
}
