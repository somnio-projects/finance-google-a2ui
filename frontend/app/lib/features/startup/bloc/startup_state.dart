part of 'startup_bloc.dart';

/// What the start-up surface draws.
///
/// No [failure] is the neutral wait. A [failure] is the registry's own
/// sentence and, once [canRetry], the *Try again* that asks it again.
final class StartupState extends Equatable {
  /// Creates the state; the default is the neutral wait.
  const StartupState({this.failure, this.canRetry = false});

  /// Why the registry could not answer, verbatim; null while waiting.
  final AppFailure? failure;

  /// Whether *Try again* is offered — false inside a `Retry-After` window.
  final bool canRetry;

  @override
  List<Object?> get props => <Object?>[failure, canRetry];
}
