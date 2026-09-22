part of 'sign_in_bloc.dart';

/// What the sign-in screen can be asked to do.
sealed class SignInEvent extends Equatable {
  const SignInEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// `Continue with Google`.
final class SignInGoogleRequested extends SignInEvent {
  /// Creates the event.
  const SignInGoogleRequested();
}

/// `Continue with email`.
final class SignInEmailSubmitted extends SignInEvent {
  /// Creates the event.
  const SignInEmailSubmitted(this.email);

  /// What the person typed.
  final String email;

  @override
  List<Object?> get props => <Object?>[email];
}

/// The person came back through the e-mail link.
final class SignInLinkCompleted extends SignInEvent {
  /// Creates the event.
  const SignInLinkCompleted({required this.email, required this.link});

  /// The e-mail the link was sent to.
  final String email;

  /// The link itself.
  final Uri link;

  @override
  List<Object?> get props => <Object?>[email, link];
}

/// `Request access`.
final class SignInAccessRequested extends SignInEvent {
  /// Creates the event.
  const SignInAccessRequested(this.email);

  /// The mailbox asking for an invitation.
  final String email;

  @override
  List<Object?> get props => <Object?>[email];
}

/// `Dismiss` on the snackbar.
final class SignInMessageDismissed extends SignInEvent {
  /// Creates the event.
  const SignInMessageDismissed();
}
