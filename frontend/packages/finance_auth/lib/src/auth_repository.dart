import 'dart:async';

import 'package:finance_auth/src/access_admission.dart';
import 'package:finance_auth/src/access_decision.dart';
import 'package:finance_auth/src/access_gateway.dart';
import 'package:finance_auth/src/auth_session.dart';
import 'package:finance_auth/src/auth_state.dart';
import 'package:finance_auth/src/email_sign_in_outcome.dart';
import 'package:finance_auth/src/identity_provider.dart';
import 'package:finance_auth/src/sign_in_policy.dart';
import 'package:finance_core/finance_core.dart';

/// Joins *who* (the identity provider) with *whether* (the registry).
///
/// Every sign-in ends in [AccessGateway.access]: a token the registry does
/// not recognise leaves the person [AuthStatus.notProvisioned] with the
/// backend's sentence, and no shell. Sign-out clears both halves and tells
/// `onSignedOut`, which is where the views cache is emptied (G-3).
class AuthRepository {
  /// Creates the repository.
  AuthRepository({
    required IdentityProvider identity,
    required AccessGateway access,
    void Function()? onSignedOut,
  }) : _identity = identity,
       _access = access,
       _onSignedOut = onSignedOut;

  final IdentityProvider _identity;
  final AccessGateway _access;
  final void Function()? _onSignedOut;
  final StreamController<AuthState> _changes =
      StreamController<AuthState>.broadcast();
  AuthState _state = const AuthState();

  /// Where the person stands now.
  AuthState get state => _state;

  /// Every change of [state], for the router and the screens.
  Stream<AuthState> get changes => _changes.stream;

  /// Whether the provider can send an e-mail link (else the preview path).
  bool get usesEmailLink => _identity.isConfigured;

  /// The bearer for every request: the provider's fresh token, else the
  /// minted one, else nothing.
  Future<String?> token() async {
    final session = _state.session;
    if (session == null) return null;
    if (session.provider == 'preview') return session.token;
    return await _identity.currentToken() ?? session.token;
  }

  /// A provider session survived a reload: ask the registry again, as
  /// [AuthStatus.restoring] so no sign-in form is drawn meanwhile (GGU-163).
  Future<void> restore() async {
    final token = await _identity.currentToken();
    if (token == null) {
      _emit(const AuthState(status: AuthStatus.signedOut));
      return;
    }
    await _admit(
      AuthSession(token: token, provider: 'firebase'),
      pending: AuthStatus.restoring,
    );
  }

  /// *Try again* after [AuthStatus.unavailable]: same session (GGU-159).
  Future<void> retry() async {
    final session = _state.session;
    if (_state.status != AuthStatus.unavailable || session == null) return;
    await _admit(session, pending: AuthStatus.restoring);
  }

  /// The e-mail button: a link where a provider exists, a minted token where
  /// none does. [continueUrl] is where the link brings the person back.
  Future<Result<EmailSignInOutcome>> signInWithEmail(
    String email, {
    required Uri continueUrl,
  }) async {
    if (!_identity.isConfigured) {
      return emailOutcome(
        await _complete(_access.previewSignIn(email)),
        EmailSignInOutcome.signedIn,
      );
    }
    return emailOutcome(
      await _identity.sendEmailLink(email, continueUrl: continueUrl),
      EmailSignInOutcome.linkSent,
    );
  }

  /// Whether [link] finishes an e-mail sign-in.
  bool isEmailLink(Uri link) => _identity.isEmailLink(link);

  /// The person came back through a sign-in [link].
  Future<Result<void>> completeEmailLink(String email, Uri link) =>
      _complete(_identity.signInWithEmailLink(email, link));

  /// The *Request access* link.
  Future<Result<void>> requestAccess(String email) =>
      _access.requestAccess(email);

  /// Which door this deployment has (spec backend/0043).
  Future<Result<SignInPolicy>> signInPolicy() => _access.signInPolicy();

  /// Ends the session everywhere.
  Future<void> signOut() async {
    await _identity.signOut();
    _onSignedOut?.call();
    _emit(const AuthState(status: AuthStatus.signedOut));
  }

  /// The server answered 401 to a signed-in call: the session is over.
  /// Said at once, so an access check that got the 401 reads it as ended.
  void handleUnauthenticated() {
    if (_state.status == AuthStatus.signedOut) return;
    _emit(const AuthState(status: AuthStatus.signedOut));
    unawaited(signOut());
  }

  Future<Result<void>> _complete(Future<Result<AuthSession>> attempt) async =>
      switch (await attempt) {
        Err<AuthSession>(:final failure) => Err<void>(failure),
        Ok<AuthSession>(:final value) => await _admit(value),
      };

  Future<Result<void>> _admit(
    AuthSession session, {
    AuthStatus pending = AuthStatus.provisioning,
  }) async {
    // Emitted, not just assigned: the registry may be writing a first row
    // before it can answer (spec `backend/0040`), and that wait is a state.
    _emit(AuthState(status: pending, session: session));
    final answer = await _access.access();
    // A 401 on this very call has already ended the session; keep that.
    if (_state.status != AuthStatus.signedOut) {
      _emit(admission(answer, session));
    }
    return switch (answer) {
      Err<AccessDecision>(:final failure) => Err<void>(failure),
      Ok<AccessDecision>() => const Ok<void>(null),
    };
  }

  void _emit(AuthState next) {
    _state = next;
    _changes.add(next);
  }
}
