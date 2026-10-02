import 'package:finance_auth/finance_auth.dart';
import 'package:finance_core/finance_core.dart';
import 'package:test/test.dart';

import '../auth_harness.dart';

void main() {
  group(AuthRepository, () {
    late ScriptedIdentity identity;
    late FakeBackend backend;
    late List<AuthState> seen;
    var signedOutCalls = 0;

    AuthRepository build() {
      final repository = AuthRepository(
        identity: identity,
        access: AccessGateway(apiClient: backend.client),
        onSignedOut: () => signedOutCalls++,
      );
      repository.changes.listen(seen.add);
      return repository;
    }

    setUp(() {
      identity = ScriptedIdentity();
      backend = FakeBackend();
      seen = <AuthState>[];
      signedOutCalls = 0;
    });

    test('starts unknown, with no token', () async {
      final repository = build();
      expect(repository.state, equals(const AuthState()));
      expect(await repository.token(), isNull);
      expect(repository.usesEmailLink, isTrue);
    });

    test('restore finds nobody and settles on signed out', () async {
      final repository = build();
      await repository.restore();
      expect(repository.state.status, AuthStatus.signedOut);
      expect(backend.requests, isEmpty);
    });

    test('restore finds a provider session and asks the registry', () async {
      identity.restored = 'restored-token';
      final repository = build();
      await repository.restore();
      expect(repository.state.status, AuthStatus.signedIn);
      expect(repository.state.decision?.provisioned, isTrue);
      expect(
        backend.requests.single.headers['authorization'],
        'Bearer session',
      );
    });

    test(
      "Google admits an invited person and the token is the provider's",
      () async {
        identity
          ..google = const Ok<AuthSession>(firebaseSession)
          ..restored = 'fresh-token';
        final repository = build();
        expect((await repository.signInWithGoogle()).isOk, isTrue);
        expect(repository.state.allowsShell, isTrue);
        expect(repository.state.session, firebaseSession);
        // Firebase refreshes its own token; the repository always asks it.
        expect(await repository.token(), 'fresh-token');
      },
    );

    test(
      'Google without a registry row is not provisioned, and keeps no session',
      () async {
        identity.google = const Ok<AuthSession>(firebaseSession);
        backend.provisioned = false;
        final repository = build();
        expect((await repository.signInWithGoogle()).isOk, isTrue);
        expect(repository.state.status, AuthStatus.notProvisioned);
        expect(repository.state.session, isNull);
        expect(repository.state.decision?.message, 'Not provisioned.');
        expect(await repository.token(), isNull);
      },
    );

    test(
      'a provider refusal is the failure, and the state does not move',
      () async {
        final repository = build();
        final result = await repository.signInWithGoogle();
        expect(result.failureOrNull, isA<TransportFailure>());
        expect(seen, isEmpty);
      },
    );

    test('a registry that cannot be reached signs the person out', () async {
      identity.google = const Ok<AuthSession>(firebaseSession);
      backend.accessStatus = 503;
      final repository = build();
      final result = await repository.signInWithGoogle();
      expect(result.isOk, isFalse);
      expect(repository.state.status, AuthStatus.signedOut);
    });
  });
}
