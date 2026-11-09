import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/sign_in/bloc/sign_in_bloc.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:finance_core/finance_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/auth_fakes.dart';

void main() {
  group(SignInBloc, () {
    final url = Uri.parse('http://localhost:5173/sign-in');
    final link = Uri.parse('http://localhost:5173/sign-in?mode=signIn');

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
      'the e-mail link admits an invited person and ends idle',
      build: () => build(
        fakeAuthRepository(
          identity: FakeIdentity(isConfigured: true),
          provisionedEmails: const <String>{'a@b.test'},
        ),
      ),
      act: (bloc) =>
          bloc.add(SignInLinkCompleted(email: 'a@b.test', link: link)),
      expect: () => const <SignInState>[
        SignInState(status: SignInStatus.busy, email: 'a@b.test'),
        // The backend has not answered yet, and on a first sign-in it may be
        // enrolling this identity (spec backend/0040). The screen says so.
        SignInState(status: SignInStatus.provisioning, email: 'a@b.test'),
        SignInState(email: 'a@b.test'),
      ],
    );

    blocTest<SignInBloc, SignInState>(
      "the e-mail link for an uninvited person shows the backend's sentence",
      build: () => build(
        fakeAuthRepository(
          identity: FakeIdentity(isConfigured: true),
          provisionedEmails: const <String>{},
        ),
      ),
      act: (bloc) =>
          bloc.add(SignInLinkCompleted(email: 'a@b.test', link: link)),
      expect: () => const <SignInState>[
        SignInState(status: SignInStatus.busy, email: 'a@b.test'),
        SignInState(status: SignInStatus.provisioning, email: 'a@b.test'),
        SignInState(
          email: 'a@b.test',
          message: "This account isn't provisioned for the preview.",
        ),
      ],
    );

    blocTest<SignInBloc, SignInState>(
      "an e-mail link the provider refuses shows the provider's sentence",
      build: () => build(
        fakeAuthRepository(
          identity: FakeIdentity(isConfigured: true)
            ..linked = const Err<AuthSession>(
              TransportFailure('The link expired.'),
            ),
        ),
      ),
      act: (bloc) =>
          bloc.add(SignInLinkCompleted(email: 'a@b.test', link: link)),
      expect: () => const <SignInState>[
        SignInState(status: SignInStatus.busy, email: 'a@b.test'),
        SignInState(email: 'a@b.test', message: 'The link expired.'),
      ],
    );

    test('events are values', () {
      expect(
        SignInEmailSubmitted('a'.toUpperCase()),
        const SignInEmailSubmitted('A'),
      );
      expect(const SignInAccessRequested('a').props, <Object?>['a']);
      expect(const SignInMessageDismissed().props, isEmpty);
      expect(
        SignInLinkCompleted(email: 'a', link: Uri.parse('http://x')).props,
        hasLength(2),
      );
    });
  });
}
