import 'dart:async';

import 'package:finance_auth/src/access_decision.dart';
import 'package:finance_auth/src/access_gateway.dart';
import 'package:finance_auth/src/auth_session.dart';
import 'package:finance_auth/src/auth_state.dart';
import 'package:finance_auth/src/email_sign_in_outcome.dart';
import 'package:finance_auth/src/identity_provider.dart';
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

  /// A provider session survived a reload: ask the registry again.
  Future<void> restore() async {
    final token = await _identity.currentToken();
    if (token == null) {
      _emit(const AuthState(status: AuthStatus.signedOut));
      return;
    }
    await _admit(AuthSession(token: token, provider: 'firebase'));
  }

  /// The Google button.
  Future<Result<void>> signInWithGoogle() =>
      _complete(_identity.signInWithGoogle());

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

  /// Ends the session everywhere.
  Future<void> signOut() async {
    await _identity.signOut();
    _onSignedOut?.call();
    _emit(const AuthState(status: AuthStatus.signedOut));
  }

  /// The server answered 401 to a signed-in call: the session is over.
  void handleUnauthenticated() {
    if (_state.status == AuthStatus.signedOut) return;
    unawaited(signOut());
  }

  Future<Result<void>> _complete(Future<Result<AuthSession>> attempt) async {
    switch (await attempt) {
      case Err<AuthSession>(:final failure):
        return Err<void>(failure);
      case Ok<AuthSession>(:final value):
        return await _admit(value);
    }
  }

  Future<Result<void>> _admit(AuthSession session) async {
    _state = AuthState(session: session);
    switch (await _access.access()) {
      case Err<AccessDecision>(:final failure):
        _emit(const AuthState(status: AuthStatus.signedOut));
        return Err<void>(failure);
      case Ok<AccessDecision>(:final value):
        _emit(
          AuthState(
            status: value.provisioned
                ? AuthStatus.signedIn
                : AuthStatus.notProvisioned,
            session: value.provisioned ? session : null,
            decision: value,
          ),
        );
        return const Ok<void>(null);
    }
  }

  void _emit(AuthState next) {
    _state = next;
    _changes.add(next);
  }
}
