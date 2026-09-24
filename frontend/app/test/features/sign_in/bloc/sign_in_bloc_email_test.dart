import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/sign_in/bloc/sign_in_bloc.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/auth_fakes.dart';

void main() {
  group(SignInBloc, () {
    final url = Uri.parse('http://localhost:5173/sign-in');

    SignInBloc build(AuthRepository auth) =>
        SignInBloc(authRepository: auth, continueUrl: url);

    blocTest<SignInBloc, SignInState>(
      'e-mail on the local stack signs in',
      build: () => build(fakeAuthRepository()),
      act: (bloc) => bloc.add(const SignInEmailSubmitted('demo@somnio.dev')),
      expect: () => const <SignInState>[
        SignInState(status: SignInStatus.busy, email: 'demo@somnio.dev'),
        // The backend has not answered yet; on a first sign-in it may be
        // enrolling this identity (spec backend/0040).
        SignInState(
          status: SignInStatus.provisioning,
          email: 'demo@somnio.dev',
        ),
        SignInState(email: 'demo@somnio.dev'),
      ],
    );

    blocTest<SignInBloc, SignInState>(
      'e-mail refused by the backend shows its problem detail, verbatim',
      build: () => build(fakeAuthRepository()),
      act: (bloc) => bloc.add(const SignInEmailSubmitted('nobody@y.test')),
      expect: () => const <SignInState>[
        SignInState(status: SignInStatus.busy, email: 'nobody@y.test'),
        SignInState(
          email: 'nobody@y.test',
          message: "This account isn't provisioned for the preview.",
        ),
      ],
    );

    blocTest<SignInBloc, SignInState>(
      'e-mail with a provider sends a link',
      build: () =>
          build(fakeAuthRepository(identity: FakeIdentity(isConfigured: true))),
      act: (bloc) => bloc.add(const SignInEmailSubmitted('demo@somnio.dev')),
      expect: () => const <SignInState>[
        SignInState(status: SignInStatus.busy, email: 'demo@somnio.dev'),
        SignInState(status: SignInStatus.linkSent, email: 'demo@somnio.dev'),
      ],
    );

    blocTest<SignInBloc, SignInState>(
      'coming back through the link finishes the sign-in',
      build: () =>
          build(fakeAuthRepository(identity: FakeIdentity(isConfigured: true))),
      act: (bloc) => bloc.add(
        SignInLinkCompleted(
          email: 'demo@somnio.dev',
          link: Uri.parse('http://x/?mode=signIn'),
        ),
      ),
      expect: () => const <SignInState>[
        SignInState(status: SignInStatus.busy, email: 'demo@somnio.dev'),
        // The backend has not answered yet; on a first sign-in it may be
        // enrolling this identity (spec backend/0040).
        SignInState(
          status: SignInStatus.provisioning,
          email: 'demo@somnio.dev',
        ),
        SignInState(email: 'demo@somnio.dev'),
      ],
    );

    blocTest<SignInBloc, SignInState>(
      'a request for access is acknowledged; a dismissal clears the message',
      build: () => build(fakeAuthRepository()),
      act: (bloc) => bloc
        ..add(const SignInAccessRequested('you@company.com'))
        ..add(const SignInMessageDismissed()),
      expect: () => const <SignInState>[
        SignInState(status: SignInStatus.busy),
        SignInState(status: SignInStatus.requested),
      ],
    );

    blocTest<SignInBloc, SignInState>(
      'a failed request for access is reported',
      build: () => build(
        AuthRepository(
          identity: FakeIdentity(),
          access: AccessGateway(apiClient: fakeAuthRepositoryApi(status: 503)),
        ),
      ),
      act: (bloc) => bloc.add(const SignInAccessRequested('you@company.com')),
      expect: () => <dynamic>[
        const SignInState(status: SignInStatus.busy),
        isA<SignInState>().having((s) => s.message, 'message', isNotNull),
      ],
    );
  });
}
