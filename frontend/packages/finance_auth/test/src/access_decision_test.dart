import 'package:finance_auth/finance_auth.dart';
import 'package:finance_core/finance_core.dart';
import 'package:test/test.dart';

void main() {
  _authStateIsAValue();
  group(AccessDecision, () {
    test('reads every field the backend sends', () {
      final decision = AccessDecision.fromJson(<String, dynamic>{
        'email': 'a@b.test',
        'provisioned': true,
        'status': 'active',
        'role': 'admin',
        'display_name': 'Alex',
        'message': 'Welcome back.',
      }).valueOrNull;
      expect(
        decision,
        const AccessDecision(
          provisioned: true,
          message: 'Welcome back.',
          email: 'a@b.test',
          status: 'active',
          role: 'admin',
          displayName: 'Alex',
        ),
      );
    });

    test('names the field it lacks rather than guessing (N-3)', () {
      expect(
        AccessDecision.fromJson('nope').failureOrNull,
        isA<ContractFailure>(),
      );
      expect(
        (AccessDecision.fromJson(<String, dynamic>{'message': 'm'})
                    .failureOrNull!
                as ContractFailure)
            .path,
        'provisioned',
      );
      expect(
        (AccessDecision.fromJson(<String, dynamic>{'provisioned': false})
                    .failureOrNull!
                as ContractFailure)
            .path,
        'message',
      );
    });
  });

  group(NullIdentityProvider, () {
    test('declines every provider call, and says why', () async {
      const identity = NullIdentityProvider();
      expect(identity.isConfigured, isFalse);
      expect(await identity.currentToken(), isNull);
      expect(
        (await identity.signInWithGoogle()).failureOrNull?.message,
        googleNotConfigured,
      );
      expect(
        (await identity.sendEmailLink(
          'a@b.test',
          continueUrl: Uri.parse('http://x'),
        )).isOk,
        isFalse,
      );
      expect(identity.isEmailLink(Uri.parse('http://x')), isFalse);
      expect(
        (await identity.signInWithEmailLink(
          'a@b.test',
          Uri.parse('http://x'),
        )).isOk,
        isFalse,
      );
      await identity.signOut();
    });
  });

  group(AuthSession, () {
    test('is a value', () {
      expect(firebase('t'), equals(firebase('t')));
      expect(firebase('t'), isNot(equals(firebase('u'))));
    });
  });
}

AuthSession firebase(String token) =>
    AuthSession(token: token, provider: 'firebase', email: 'a@b.test');

void _authStateIsAValue() {
  group(AuthState, () {
    test('is a value and only signedIn opens the shell', () {
      final decision = AccessDecision.fromJson(<String, dynamic>{
        'provisioned': true,
        'message': 'Welcome back.',
      }).valueOrNull;
      final a = AuthState(
        status: AuthStatus.signedIn,
        session: firebase('t'),
        decision: decision,
      );
      final b = AuthState(
        status: AuthStatus.signedIn,
        session: firebase('t'),
        decision: decision,
      );
      expect(a, equals(b));
      expect(a.props, hasLength(3));
      expect(a.allowsShell, isTrue);
      expect(
        const AuthState(status: AuthStatus.notProvisioned).allowsShell,
        isFalse,
      );
    });
  });
}
