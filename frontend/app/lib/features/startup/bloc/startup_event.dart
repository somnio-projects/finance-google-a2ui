part of 'startup_bloc.dart';

/// What the start-up surface can be told.
sealed class StartupEvent extends Equatable {
  const StartupEvent();
}

/// The repository moved; [auth] is where the person stands now.
final class StartupAuthChanged extends StartupEvent {
  /// Creates the event.
  const StartupAuthChanged(this.auth);

  /// The repository's new state.
  final AuthState auth;

  @override
  List<Object?> get props => <Object?>[auth];
}

/// *Try again*.
final class StartupRetryRequested extends StartupEvent {
  /// Creates the event.
  const StartupRetryRequested();

  @override
  List<Object?> get props => const <Object?>[];
}
