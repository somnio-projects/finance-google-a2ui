import 'package:equatable/equatable.dart';
import 'package:finance_auth/src/access_decision.dart';
import 'package:finance_auth/src/auth_session.dart';

/// Where the person stands with the app.
enum AuthStatus {
  /// Not decided yet — the provider is being asked for a restored session.
  unknown,

  /// Nobody is signed in.
  signedOut,

  /// Signed in and invited: the shell may open.
  signedIn,

  /// The provider vouched for them, the registry did not (spec 0027 AC-1).
  notProvisioned,
}

/// The one value the router gates on.
class AuthState extends Equatable {
  /// Creates the state.
  const AuthState({
    this.status = AuthStatus.unknown,
    this.session,
    this.decision,
  });

  /// Where the person stands.
  final AuthStatus status;

  /// The credential, while signed in.
  final AuthSession? session;

  /// The backend's decision, once asked.
  final AccessDecision? decision;

  /// Whether the shell may open.
  bool get allowsShell => status == AuthStatus.signedIn;

  @override
  List<Object?> get props => <Object?>[status, session, decision];
}
