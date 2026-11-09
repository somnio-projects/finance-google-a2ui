import 'package:finance_auth/src/auth_session.dart';
import 'package:finance_core/finance_core.dart';

/// The identity seam: whoever proves *who* the person is.
///
/// The Flutter app implements it over Firebase Auth; this package ships the
/// [NullIdentityProvider] for a stack with no identity provider configured,
/// where the design's e-mail path is answered by the backend's preview
/// sign-in instead.
abstract interface class IdentityProvider {
  /// Whether an identity provider exists in this build at all.
  bool get isConfigured;

  /// The token of the person already signed in with the provider, if any —
  /// refreshed by the provider, so the same call is used before every request.
  Future<String?> currentToken();

  /// Sends a sign-in link to [email] that returns to [continueUrl].
  Future<Result<void>> sendEmailLink(String email, {required Uri continueUrl});

  /// Whether [link] is a sign-in link this provider issued.
  bool isEmailLink(Uri link);

  /// Finishes an e-mail sign-in: the person came back through [link].
  Future<Result<AuthSession>> signInWithEmailLink(String email, Uri link);

  /// Ends the provider's session.
  Future<void> signOut();
}

/// The sentence the e-mail path shows when no provider is configured.
const String identityNotConfigured =
    'Sign-in is not configured for this build.';

/// No identity provider: every provider call declines, honestly.
final class NullIdentityProvider implements IdentityProvider {
  /// Creates the null provider.
  const NullIdentityProvider();

  @override
  bool get isConfigured => false;

  @override
  Future<String?> currentToken() async => null;

  @override
  Future<Result<void>> sendEmailLink(
    String email, {
    required Uri continueUrl,
  }) async => const Err<void>(TransportFailure(identityNotConfigured));

  @override
  bool isEmailLink(Uri link) => false;

  @override
  Future<Result<AuthSession>> signInWithEmailLink(
    String email,
    Uri link,
  ) async => const Err<AuthSession>(TransportFailure(identityNotConfigured));

  @override
  Future<void> signOut() async {}
}
