import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/sign_in/bloc/sign_in_bloc.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:finance_core/finance_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/auth_fakes.dart';

void main() {
  group(SignInBloc, () {
    final url = Uri.parse('http://localhost:5173/sign-in');
    const session = AuthSession(
      token: 'id',
      provider: 'firebase',
      email: 'demo@somnio.dev',
    );

    SignInBloc build(AuthRepository auth) =>
        SignInBloc(authRepository: auth, continueUrl: url);

    test('starts idle and says which e-mail path this build has', () {
      expect(build(fakeAuthRepository()).state, const SignInState());
      expect(build(fakeAuthRepository()).usesEmailLink, isFalse);
      expect(
        build(fakeAuthRepository(identity: FakeIdentity(isConfigured: true)))
            .usesEmailLink,
        isTrue,
      );
    });

    blocTest<SignInBloc, SignInState>(
      'Google admits and ends idle with no message',
      build: () => build(
        fakeAuthRepository(
          identity: FakeIdentity(isConfigured: true)
            ..google = const Ok<AuthSession>(session),
        ),
      ),
      act: (bloc) => bloc.add(const SignInGoogleRequested()),
      expect: () => const <SignInState>[
        SignInState(status: SignInStatus.busy),
        SignInState(),
      ],
    );

    blocTest<SignInBloc, SignInState>(
      "Google refused by the provider shows the provider's sentence",
      build: () => build(fakeAuthRepository()),
      act: (bloc) => bloc.add(const SignInGoogleRequested()),
      expect: () => const <SignInState>[
        SignInState(status: SignInStatus.busy),
        SignInState(message: googleNotConfigured),
      ],
    );

    blocTest<SignInBloc, SignInState>(
      "Google for an uninvited person shows the backend's sentence",
      build: () => build(
        fakeAuthRepository(
          identity: FakeIdentity(isConfigured: true)
            ..google = const Ok<AuthSession>(
              AuthSession(token: 'id', provider: 'firebase', email: 'x@y.test'),
            ),
          provisionedEmails: const <String>{},
        ),
      ),
      act: (bloc) => bloc.add(const SignInGoogleRequested()),
      expect: () => const <SignInState>[
        SignInState(status: SignInStatus.busy),
        SignInState(message: "This account isn't provisioned for the preview."),
      ],
    );

    test('events are values', () {
      expect(
        SignInEmailSubmitted('a'.toUpperCase()),
        const SignInEmailSubmitted('A'),
      );
      expect(const SignInAccessRequested('a').props, <Object?>['a']);
      expect(const SignInGoogleRequested().props, isEmpty);
      expect(
        SignInLinkCompleted(email: 'a', link: Uri.parse('http://x')).props,
        hasLength(2),
      );
    });
  });
}
