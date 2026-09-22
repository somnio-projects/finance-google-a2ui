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

    test('e-mail sends a link where a provider exists', () async {
      final repository = build();
      final result = await repository.signInWithEmail(
        'a@b.test',
        continueUrl: Uri.parse('http://localhost:5173/sign-in'),
      );
      expect(result.valueOrNull, EmailSignInOutcome.linkSent);
      expect(identity.calls, <String>['link:a@b.test']);
      expect(identity.continueUrl?.path, '/sign-in');
      expect(
        repository.isEmailLink(Uri.parse('http://x/?mode=signIn')),
        isTrue,
      );
    });

    test('a link failure is reported', () async {
      identity.link = const Err<void>(TransportFailure('quota'));
      final repository = build();
      final result = await repository.signInWithEmail(
        'a@b.test',
        continueUrl: Uri.parse('http://x'),
      );
      expect(result.failureOrNull, isA<TransportFailure>());
    });

    test('e-mail on a bare stack mints a preview token and admits', () async {
      identity = ScriptedIdentity(isConfigured: false);
      final repository = build();
      expect(repository.usesEmailLink, isFalse);
      final result = await repository.signInWithEmail(
        'demo@somnio.dev',
        continueUrl: Uri.parse('http://x'),
      );
      expect(result.valueOrNull, EmailSignInOutcome.signedIn);
      expect(repository.state.session?.provider, 'preview');
      expect(await repository.token(), 'minted');
      expect(
        backend.requests.first.headers.containsKey('authorization'),
        isFalse,
      );
    });

    test(
      "a refused preview e-mail is the backend's problem, verbatim",
      () async {
        identity = ScriptedIdentity(isConfigured: false);
        backend.previewToken = null;
        final repository = build();
        final result = await repository.signInWithEmail(
          'x@y.test',
          continueUrl: Uri.parse('http://x'),
        );
        expect(result.isOk, isFalse);
        expect(repository.state.status, AuthStatus.unknown);
      },
    );

    test('coming back through the link completes the sign-in', () async {
      identity.linked = const Ok<AuthSession>(firebaseSession);
      final repository = build();
      final result = await repository.completeEmailLink(
        'a@b.test',
        Uri.parse('http://x/?mode=signIn'),
      );
      expect(result.isOk, isTrue);
      expect(repository.state.allowsShell, isTrue);
    });

    test('request access posts the e-mail without a token', () async {
      final repository = build();
      expect((await repository.requestAccess('you@company.com')).isOk, isTrue);
      expect(backend.requests.single.url.path, '/v1/access-requests');
      expect(
        backend.requests.single.headers.containsKey('authorization'),
        isFalse,
      );
    });

    test('sign-out clears both halves and empties the cache once', () async {
      identity.google = const Ok<AuthSession>(firebaseSession);
      final repository = build();
      await repository.signInWithGoogle();
      await repository.signOut();
      expect(repository.state, const AuthState(status: AuthStatus.signedOut));
      expect(identity.calls.last, 'signOut');
      expect(signedOutCalls, 1);
    });

    test('a 401 ends the session, and is ignored when there is none', () async {
      identity.google = const Ok<AuthSession>(firebaseSession);
      final repository = build();
      await repository.signInWithGoogle();
      repository.handleUnauthenticated();
      await Future<void>.delayed(Duration.zero);
      expect(repository.state.status, AuthStatus.signedOut);
      repository.handleUnauthenticated();
      await Future<void>.delayed(Duration.zero);
      expect(signedOutCalls, 1);
    });
  });
}
