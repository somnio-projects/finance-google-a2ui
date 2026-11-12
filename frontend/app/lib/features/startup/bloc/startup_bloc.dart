import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:finance_core/finance_core.dart';

part 'startup_event.dart';
part 'startup_state.dart';

/// Waits out [duration]. Injected so a test decides when a window ends; the
/// app's is [Future.delayed], a timer rather than a read of the clock.
typedef StartupWait = Future<void> Function(Duration duration);

Future<void> _delay(Duration duration) => Future<void>.delayed(duration);

/// The start-up surface: a neutral wait while the session is restored, and
/// the way out when the registry could not answer (GGU-163, GGU-159).
///
/// Which screen shows is the router's decision (`AuthGate`); this bloc only
/// says what the start-up surface draws while it is the one showing.
class StartupBloc extends Bloc<StartupEvent, StartupState> {
  /// Creates the bloc over the one repository.
  StartupBloc({required AuthRepository authRepository, StartupWait? wait})
    : _auth = authRepository,
      _wait = wait ?? _delay,
      super(const StartupState()) {
    on<StartupAuthChanged>(_onAuthChanged);
    on<StartupRetryRequested>(_onRetry);
    _watch = _auth.changes.listen((auth) => add(StartupAuthChanged(auth)));
  }

  final AuthRepository _auth;
  final StartupWait _wait;
  late final StreamSubscription<AuthState> _watch;

  @override
  Future<void> close() async {
    await _watch.cancel();
    await super.close();
  }

  Future<void> _onAuthChanged(
    StartupAuthChanged event,
    Emitter<StartupState> emit,
  ) async {
    final failure = event.auth.failure;
    if (event.auth.status != AuthStatus.unavailable || failure == null) {
      emit(const StartupState());
      return;
    }
    // A 429 says how long to stay away (`Retry-After`): the button waits
    // that long, so *Try again* cannot be pressed into the same window.
    final window = failure is ProblemFailure ? failure.retryAfter : null;
    emit(StartupState(failure: failure, canRetry: window == null));
    if (window == null) return;
    await _wait(window);
    if (state.failure == failure) {
      emit(StartupState(failure: failure, canRetry: true));
    }
  }

  Future<void> _onRetry(
    StartupRetryRequested event,
    Emitter<StartupState> emit,
  ) async {
    if (!state.canRetry) return;
    // The repository reports the new attempt as `restoring`, which arrives
    // here as a change and draws the neutral wait again.
    await _auth.retry();
  }
}
