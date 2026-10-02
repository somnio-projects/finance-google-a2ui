import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/sign_in/bloc/sign_in_bloc.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/auth_fakes.dart';

/// The bloc's half of spec backend/0043: it holds the door, or it holds
/// nothing. There is no third state and no default.
void main() {
  group(SignInBloc, () {
    final url = Uri.parse('http://localhost:5173/sign-in');

    SignInBloc build(AuthRepository auth) =>
        SignInBloc(authRepository: auth, continueUrl: url);

    SignInBloc over(SignInPolicy policy) =>
        build(fakeAuthRepository(policy: policy));

    blocTest<SignInBloc, SignInState>(
      'an open deployment is carried into the state',
      build: () => over(SignInPolicy.open),
      act: (bloc) => bloc.add(const SignInPolicyRequested()),
      expect: () => const <SignInState>[SignInState(policy: SignInPolicy.open)],
      verify: (bloc) => expect(bloc.state.offersInvite, isFalse),
    );

    blocTest<SignInBloc, SignInState>(
      'an invite-only deployment is too, and it offers the invite',
      build: () => over(SignInPolicy.inviteOnly),
      act: (bloc) => bloc.add(const SignInPolicyRequested()),
      expect: () => const <SignInState>[
        SignInState(policy: SignInPolicy.inviteOnly),
      ],
      verify: (bloc) => expect(bloc.state.offersInvite, isTrue),
    );

    blocTest<SignInBloc, SignInState>(
      'a read that fails leaves the door unknown and emits nothing',
      build: () => build(fakeAuthRepository(policy: null)),
      act: (bloc) => bloc.add(const SignInPolicyRequested()),
      // Not "emits invite-only". A backend the screen could not reach is not
      // evidence that access is invite-only, and printing the sentence
      // anyway is the defect 0043 exists to remove (OD-5).
      expect: () => const <SignInState>[],
      verify: (bloc) {
        expect(bloc.state.policy, isNull);
        expect(bloc.state.offersInvite, isFalse);
      },
    );

    blocTest<SignInBloc, SignInState>(
      'the door does not disturb anything else the screen is doing',
      build: () => over(SignInPolicy.open),
      act: (bloc) => bloc
        ..add(const SignInPolicyRequested())
        ..add(const SignInMessageDismissed()),
      skip: 1,
      // The policy rides alongside; it neither clears a message nor busies
      // the buttons.
      verify: (bloc) {
        expect(bloc.state.policy, SignInPolicy.open);
        expect(bloc.state.status, SignInStatus.idle);
        expect(bloc.state.isBusy, isFalse);
      },
    );
  });
}
