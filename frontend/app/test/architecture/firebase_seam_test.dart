// The identity provider is a Flutter plugin, so its adapter lives in app/lib
// rather than in a pure package — which is exactly where a feature could
// reach for it directly and bypass the `IdentityProvider` seam. This pins
// the three files allowed to import the SDK (spec frontend/0008 OD-2).
import 'package:flutter_test/flutter_test.dart';

import 'workspace_sources.dart';

void main() {
  group('the Firebase seam', () {
    late WorkspaceSources sources;

    setUp(() {
      sources = WorkspaceSources.locate();
    });

    test('only the identity adapter and the entry points touch Firebase', () {
      // A Flutter plugin cannot live in packages/, so the SDK is confined to
      // the adapter, the composition root and main.dart (spec frontend/0008).
      expect(
        sources.offenders(
          'app/lib',
          <String>[
            "import 'package:firebase_auth/",
            "import 'package:firebase_core/",
          ],
          allow: <String>{
            'app/lib/auth/firebase_identity_provider.dart',
            'app/lib/bootstrap.dart',
            'app/lib/main.dart',
          },
        ),
        isEmpty,
      );
    });
  });
}
