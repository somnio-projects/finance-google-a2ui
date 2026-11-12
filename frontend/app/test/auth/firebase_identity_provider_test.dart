import 'package:finance_app/auth/firebase_error_copy.dart';
import 'package:finance_app/auth/firebase_identity_provider.dart';
import 'package:finance_core/finance_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuth extends Mock implements FirebaseAuth;

class _MockCredential extends Mock implements UserCredential;

class _MockUser extends Mock implements User;

class _FakeProvider extends Fake implements AuthProvider;

class _FakeSettings extends Fake implements ActionCodeSettings;

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeProvider());
    registerFallbackValue(_FakeSettings());
  });

  group(FirebaseIdentityProvider, () {
    late _MockAuth auth;
    late FirebaseIdentityProvider identity;

    _MockCredential credentialFor(String? token, {String? email = 'a@b.test'}) {
      final user = _MockUser();
      when(user.getIdToken).thenAnswer((_) async => token);
      when(() => user.email).thenReturn(email);
      final credential = _MockCredential();
      when(() => credential.user).thenReturn(user);
      return credential;
    }

    When<Future<UserCredential>> onLink() => when(
      () => auth.signInWithEmailLink(
        email: any(named: 'email'),
        emailLink: any(named: 'emailLink'),
      ),
    );

    setUp(() {
      auth = _MockAuth();
      identity = FirebaseIdentityProvider(auth: auth);
    });

    test("is configured, and reads the current user's token", () async {
      expect(identity.isConfigured, isTrue);
      when(() => auth.currentUser).thenReturn(null);
      when(() => auth.authStateChanges())
          .thenAnswer((_) => Stream<User?>.value(null));
      expect(await identity.currentToken(), isNull);
      final user = _MockUser();
      when(user.getIdToken).thenAnswer((_) async => 'fresh');
      when(() => auth.currentUser).thenReturn(user);
      expect(await identity.currentToken(), 'fresh');
    });

    test('waits for a persisted session the SDK is still restoring', () async {
      // GGU-163: on the web `currentUser` is null until the SDK has read its
      // persistence, and reading it then made a signed-in person nobody.
      final user = _MockUser();
      when(user.getIdToken).thenAnswer((_) async => 'restored');
      when(() => auth.currentUser).thenReturn(null);
      when(() => auth.authStateChanges())
          .thenAnswer((_) => Stream<User?>.value(user));
      expect(await identity.currentToken(), 'restored');
    });

    test("a provider error carries the SDK's sentence, or its code", () async {
      final link = Uri.parse('http://x/?mode=signIn');
      onLink().thenThrow(
        FirebaseAuthException(code: 'expired', message: 'The link expired.'),
      );
      final expired = await identity.signInWithEmailLink('a@b.test', link);
      expect(expired.failureOrNull?.message, 'The link expired.');
      onLink().thenThrow(FirebaseAuthException(code: 'network'));
      final network = await identity.signInWithEmailLink('a@b.test', link);
      expect(network.failureOrNull?.message, firebaseFallbackCopy);
    });

    test(
      'a credential without a user or a token is a contract failure',
      () async {
        final link = Uri.parse('http://x/?mode=signIn');
        final credential = _MockCredential();
        when(() => credential.user).thenReturn(null);
        onLink().thenAnswer((_) async => credential);
        final noUser = await identity.signInWithEmailLink('a@b.test', link);
        expect(noUser.failureOrNull, isA<ContractFailure>());
        onLink().thenAnswer((_) async => credentialFor(null));
        final noToken = await identity.signInWithEmailLink('a@b.test', link);
        expect(noToken.failureOrNull, isA<ContractFailure>());
      },
    );

    test(
      'the e-mail link goes out with the continue URL and comes back',
      () async {
        when(
          () => auth.sendSignInLinkToEmail(
            email: any(named: 'email'),
            actionCodeSettings: any(named: 'actionCodeSettings'),
          ),
        ).thenAnswer((_) async {});
        final sent = await identity.sendEmailLink(
          'a@b.test',
          continueUrl: Uri.parse('http://localhost:5173/sign-in'),
        );
        expect(sent.isOk, isTrue);
        final settings =
            verify(
                  () => auth.sendSignInLinkToEmail(
                    email: 'a@b.test',
                    actionCodeSettings: captureAny(named: 'actionCodeSettings'),
                  ),
                ).captured.single
                as ActionCodeSettings;
        expect(settings.url, 'http://localhost:5173/sign-in');
        expect(settings.handleCodeInApp, isTrue);

        when(() => auth.isSignInWithEmailLink(any())).thenReturn(true);
        expect(
          identity.isEmailLink(Uri.parse('http://x/?mode=signIn')),
          isTrue,
        );
        when(
          () => auth.signInWithEmailLink(
            email: any(named: 'email'),
            emailLink: any(named: 'emailLink'),
          ),
        ).thenAnswer((_) async => credentialFor('linked'));
        final result = await identity.signInWithEmailLink(
          'a@b.test',
          Uri.parse('http://x/?mode=signIn'),
        );
        expect(result.valueOrNull?.token, 'linked');
      },
    );

    test('sign-out reaches the SDK', () async {
      when(auth.signOut).thenAnswer((_) async {});
      await identity.signOut();
      verify(auth.signOut).called(1);
    });
  });
}
