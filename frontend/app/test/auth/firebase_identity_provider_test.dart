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

    setUp(() {
      auth = _MockAuth();
      identity = FirebaseIdentityProvider(auth: auth);
    });

    test("is configured, and reads the current user's token", () async {
      expect(identity.isConfigured, isTrue);
      when(() => auth.currentUser).thenReturn(null);
      expect(await identity.currentToken(), isNull);
      final user = _MockUser();
      when(user.getIdToken).thenAnswer((_) async => 'fresh');
      when(() => auth.currentUser).thenReturn(user);
      expect(await identity.currentToken(), 'fresh');
    });

    test('Google sign-in becomes a firebase session', () async {
      when(() => auth.signInWithPopup(any()))
          .thenAnswer((_) async => credentialFor('id'));
      final result = await identity.signInWithGoogle();
      expect(result.valueOrNull?.token, 'id');
      expect(result.valueOrNull?.provider, 'firebase');
      expect(result.valueOrNull?.email, 'a@b.test');
    });

    test("a provider error carries the SDK's sentence, or its code", () async {
      when(() => auth.signInWithPopup(any())).thenThrow(
        FirebaseAuthException(
          code: 'popup-closed',
          message: 'The popup was closed.',
        ),
      );
      expect(
        (await identity.signInWithGoogle()).failureOrNull?.message,
        'The popup was closed.',
      );
      when(() => auth.signInWithPopup(any()))
          .thenThrow(FirebaseAuthException(code: 'network'));
      expect(
        (await identity.signInWithGoogle()).failureOrNull?.message,
        'network',
      );
    });

    test(
      'a credential without a user or a token is a contract failure',
      () async {
        final credential = _MockCredential();
        when(() => credential.user).thenReturn(null);
        when(() => auth.signInWithPopup(any()))
            .thenAnswer((_) async => credential);
        expect(
          (await identity.signInWithGoogle()).failureOrNull,
          isA<ContractFailure>(),
        );
        when(() => auth.signInWithPopup(any()))
            .thenAnswer((_) async => credentialFor(null));
        expect(
          (await identity.signInWithGoogle()).failureOrNull,
          isA<ContractFailure>(),
        );
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
