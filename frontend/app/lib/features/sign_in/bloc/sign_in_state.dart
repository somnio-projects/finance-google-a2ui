part of 'sign_in_bloc.dart';

/// What the screen is doing.
enum SignInStatus {
  /// Waiting for a tap.
  idle,

  /// A request is in flight; the buttons are disabled.
  busy,

  /// The provider vouched for them; the backend has not answered yet.
  ///
  /// Distinct from [busy] because it can take longer and it means something
  /// the person should be told: on a first sign-in the registry is enrolling
  /// them (spec `backend/0040`). [busy] covers the popup, where "setting up
  /// your account" would be a lie.
  provisioning,

  /// The provider e-mailed a sign-in link.
  linkSent,

  /// The access request was accepted.
  requested,
}

/// The sign-in screen's state.
class SignInState extends Equatable {
  /// Creates the state.
  const SignInState({
    this.status = SignInStatus.idle,
    this.email = '',
    this.message,
  });

  /// What the screen is doing.
  final SignInStatus status;

  /// The e-mail last submitted, so a resend or a retry keeps it.
  final String email;

  /// A sentence to show in the snackbar — the backend's or the provider's.
  final String? message;

  /// Whether a request is in flight and the buttons must stay disabled.
  ///
  /// Provisioning counts: the person has already been vouched for and the
  /// backend has not answered, so offering the buttons again would invite a
  /// second sign-in on top of the first.
  bool get isBusy =>
      status == SignInStatus.busy || status == SignInStatus.provisioning;

  /// Whether to say that the account is being set up.
  bool get isProvisioning => status == SignInStatus.provisioning;

  /// A copy with the given fields replaced; [message] is a thunk so it can
  /// be set back to null.
  SignInState copyWith({
    SignInStatus? status,
    String? email,
    String? Function()? message,
  }) => SignInState(
    status: status ?? this.status,
    email: email ?? this.email,
    message: message == null ? this.message : message(),
  );

  @override
  List<Object?> get props => <Object?>[status, email, message];
}
