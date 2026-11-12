import 'package:equatable/equatable.dart';
import 'package:finance_auth/src/access_decision.dart';
import 'package:finance_auth/src/auth_session.dart';
import 'package:finance_core/finance_core.dart';

/// Where the person stands with the app.
enum AuthStatus {
  /// Not decided yet — the provider is being asked for a restored session.
  unknown,

  /// Nobody is signed in.
  signedOut,

  /// The provider vouched for them and the backend has not answered yet.
  ///
  /// It is a **state**, not a gap: the registry may be enrolling this
  /// identity for the first time (spec `backend/0040`), and a person who
  /// just signed in and sees nothing assumes it failed. The sign-in screen
  /// says what is happening while this holds.
  provisioning,

  /// Signed in and invited: the shell may open.
  signedIn,

  /// The provider vouched for them, the registry did not (spec 0027 AC-1).
  notProvisioned,

  /// A session survived a reload and the registry is being asked again.
  ///
  /// Distinct from [provisioning], which belongs to a sign-in the person is
  /// watching on the sign-in screen: this one belongs to a person who is
  /// already signed in, and showing them that screen while it holds is the
  /// defect GGU-163 reported. The router draws the neutral start-up surface.
  restoring,

  /// The provider vouched for them and the registry could not answer — a
  /// 429, a 5xx, a dropped connection (GGU-159).
  ///
  /// It is **not** a sign-out: nothing said the session is over, so the
  /// session is kept and the start-up surface offers *Try again*. Only a
  /// definitive answer — a 401 or 403, or "not provisioned" — ends it.
  unavailable,
}

/// The one value the router gates on.
class AuthState extends Equatable {
  /// Creates the state.
  const AuthState({
    this.status = AuthStatus.unknown,
    this.session,
    this.decision,
    this.failure,
  });

  /// Where the person stands.
  final AuthStatus status;

  /// The credential, while signed in.
  final AuthSession? session;

  /// The backend's decision, once asked.
  final AccessDecision? decision;

  /// Why the registry could not answer, while [AuthStatus.unavailable].
  final AppFailure? failure;

  /// Whether the shell may open.
  bool get allowsShell => status == AuthStatus.signedIn;

  /// Whether the app is still finding out who this is — the start-up
  /// surface, never the sign-in screen (GGU-163, GGU-159).
  bool get isStarting => switch (status) {
    AuthStatus.unknown ||
    AuthStatus.restoring ||
    AuthStatus.unavailable => true,
    _ => false,
  };

  @override
  List<Object?> get props => <Object?>[status, session, decision, failure];
}
