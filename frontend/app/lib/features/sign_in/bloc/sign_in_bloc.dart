import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:finance_core/finance_core.dart';

part 'sign_in_event.dart';
part 'sign_in_state.dart';

/// The sign-in screen's three buttons and the sentences they end in.
///
/// Every sentence on screen is either the design's chrome (the bloc holds
/// none of it) or a sentence the backend or the identity provider wrote,
/// carried here verbatim as [SignInState.message] (N-9).
class SignInBloc extends Bloc<SignInEvent, SignInState> {
  /// Creates the bloc over the one repository.
  SignInBloc({required AuthRepository authRepository, required Uri continueUrl})
    : _auth = authRepository,
      _continueUrl = continueUrl,
      super(const SignInState()) {
    on<SignInGoogleRequested>(_onGoogle);
    on<SignInEmailSubmitted>(_onEmail);
    on<SignInLinkCompleted>(_onLink);
    on<SignInAccessRequested>(_onAccessRequested);
    on<SignInMessageDismissed>(
      (event, emit) => emit(state.copyWith(message: () => null)),
    );
  }

  final AuthRepository _auth;
  final Uri _continueUrl;

  /// Whether the e-mail button sends a link (a provider exists) or signs in.
  bool get usesEmailLink => _auth.usesEmailLink;

  Future<void> _onGoogle(
    SignInGoogleRequested event,
    Emitter<SignInState> emit,
  ) async {
    emit(state.copyWith(status: SignInStatus.busy, message: () => null));
    _settle(await _auth.signInWithGoogle(), emit);
  }

  Future<void> _onEmail(
    SignInEmailSubmitted event,
    Emitter<SignInState> emit,
  ) async {
    emit(
      state.copyWith(
        status: SignInStatus.busy,
        email: event.email,
        message: () => null,
      ),
    );
    switch (await _auth.signInWithEmail(
      event.email,
      continueUrl: _continueUrl,
    )) {
      case Err<EmailSignInOutcome>(:final failure):
        emit(
          state.copyWith(
            status: SignInStatus.idle,
            message: () => failure.message,
          ),
        );
      case Ok<EmailSignInOutcome>(value: EmailSignInOutcome.linkSent):
        emit(state.copyWith(status: SignInStatus.linkSent));
      case Ok<EmailSignInOutcome>(value: EmailSignInOutcome.signedIn):
        _settle(const Ok<void>(null), emit);
    }
  }

  Future<void> _onLink(
    SignInLinkCompleted event,
    Emitter<SignInState> emit,
  ) async {
    emit(
      state.copyWith(
        status: SignInStatus.busy,
        email: event.email,
        message: () => null,
      ),
    );
    _settle(await _auth.completeEmailLink(event.email, event.link), emit);
  }

  Future<void> _onAccessRequested(
    SignInAccessRequested event,
    Emitter<SignInState> emit,
  ) async {
    emit(state.copyWith(status: SignInStatus.busy, message: () => null));
    switch (await _auth.requestAccess(event.email)) {
      case Err<void>(:final failure):
        emit(
          state.copyWith(
            status: SignInStatus.idle,
            message: () => failure.message,
          ),
        );
      case Ok<void>():
        emit(state.copyWith(status: SignInStatus.requested));
    }
  }

  /// A sign-in came back: the repository's state says whether it admitted.
  void _settle(Result<void> result, Emitter<SignInState> emit) {
    if (result case Err<void>(:final failure)) {
      emit(
        state.copyWith(
          status: SignInStatus.idle,
          message: () => failure.message,
        ),
      );
      return;
    }
    final auth = _auth.state;
    if (auth.status == AuthStatus.notProvisioned) {
      // The design's third state: the backend's own sentence, verbatim.
      emit(
        state.copyWith(
          status: SignInStatus.idle,
          message: () => auth.decision?.message,
        ),
      );
      return;
    }
    emit(state.copyWith(status: SignInStatus.idle));
  }
}
