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

/// The backend is deciding, and may be enrolling this identity.
final class SignInProvisioning extends SignInEvent {
  /// Creates the event.
  const SignInProvisioning();
}

/// Ask the backend which door this deployment has (spec backend/0043).
///
/// Added by the page when it builds the bloc, not by a tap: the screen needs
/// the answer to draw itself, and it needs it once (0043 OD-6). Deliberately
/// **not** added by the bloc's own constructor — a bloc that posts itself an
/// event on construction emits a state into every `blocTest` sequence that
/// has nothing to do with it, and the tests then encode the noise.
final class SignInPolicyRequested extends SignInEvent {
  /// Creates the event.
  const SignInPolicyRequested();
}
