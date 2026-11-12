import 'package:finance_auth/src/access_decision.dart';
import 'package:finance_auth/src/auth_session.dart';
import 'package:finance_auth/src/auth_state.dart';
import 'package:finance_core/finance_core.dart';

/// Where the registry's [answer] about [session] leaves the person.
///
/// Split from `AuthRepository` for the line budget; it is the one place that
/// decides what an answer from `GET /v1/me/access` *means*.
AuthState admission(Result<AccessDecision> answer, AuthSession session) =>
    switch (answer) {
      Ok<AccessDecision>(:final value) => AuthState(
        status: value.provisioned
            ? AuthStatus.signedIn
            : AuthStatus.notProvisioned,
        session: value.provisioned ? session : null,
        decision: value,
      ),
      Err<AccessDecision>(:final failure) when endsSession(failure) =>
        const AuthState(status: AuthStatus.signedOut),
      Err<AccessDecision>(:final failure) => AuthState(
        status: AuthStatus.unavailable,
        session: session,
        failure: failure,
      ),
    };

/// Whether [failure], from `GET /v1/me/access`, means the session is over.
///
/// Only an answer **about the credential** does: a 401 (the token is no
/// good) or a 403 (it is good and this person may not in). Everything else —
/// a 429 with `Retry-After`, a 5xx, a gateway's HTML page, a dropped
/// connection, an unreadable body — says nothing about who this is, and used
/// to sign a perfectly valid session out (GGU-159). Those leave the person
/// [AuthStatus.unavailable] with their session, and the screen offers a
/// retry instead of the sign-in form.
///
/// A bare 401 (no problem document) never reaches this question: the
/// transport has already reported it through `onUnauthenticated`, which
/// ends the session before the failure gets back here.
bool endsSession(AppFailure failure) => switch (failure) {
  ProblemFailure(:final problem) =>
    problem.status == 401 || problem.status == 403,
  _ => false,
};
