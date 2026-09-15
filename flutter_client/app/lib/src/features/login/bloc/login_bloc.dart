import 'package:bloc/bloc.dart';

import 'login_event.dart';
import 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc() : super(const LoginState()) {
    on<LoginSubmitted>(_onSubmitted);
  }

  static const Duration _fakeLoginDelay = Duration(seconds: 2);

  /// Fake login: accepts any credentials after a short delay.
  Future<void> _onSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    if (state.isLoading) return;
    emit(state.copyWith(status: LoginStatus.loading));

    await Future<void>.delayed(_fakeLoginDelay);

    emit(state.copyWith(status: LoginStatus.success));
  }
}
