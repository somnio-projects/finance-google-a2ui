import 'package:finance_app/auth/firebase_error_copy.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:finance_core/finance_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Auth as the [IdentityProvider] (ADR-B D-1: the ID token is the
/// credential; the refresh token never leaves the SDK).
///
/// The only file in `lib/` that imports `firebase_auth`, and constructed by
/// `bootstrap.dart` alone. Every provider error becomes a [TransportFailure]
/// carrying the SDK's own sentence, which the sign-in screen shows verbatim.
class FirebaseIdentityProvider implements IdentityProvider {
  /// Creates the provider over an initialised [FirebaseAuth].
  const FirebaseIdentityProvider({required FirebaseAuth auth}) : _auth = auth;

  final FirebaseAuth _auth;

  @override
  bool get isConfigured => true;

  /// The signed-in user's token, once the SDK has finished restoring them.
  ///
  /// On the web `currentUser` is null for a moment after start-up while the
  /// SDK reads its persisted session; reading it then reported a signed-in
  /// person as nobody (GGU-163). `authStateChanges()` emits once that read is
  /// done — the user, or null — so a null `currentUser` waits for it.
  @override
  Future<String?> currentToken() async {
    final user = _auth.currentUser ?? await _auth.authStateChanges().first;
    return await user?.getIdToken();
  }

  @override
  Future<Result<void>> sendEmailLink(
    String email, {
    required Uri continueUrl,
  }) => _attempt(() async {
    await _auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: ActionCodeSettings(
        url: continueUrl.toString(),
        handleCodeInApp: true,
      ),
    );
    return const Ok<void>(null);
  });

  @override
  bool isEmailLink(Uri link) => _auth.isSignInWithEmailLink(link.toString());

  @override
  Future<Result<AuthSession>> signInWithEmailLink(String email, Uri link) =>
      _attempt(() async {
        final credential = await _auth.signInWithEmailLink(
          email: email,
          emailLink: link.toString(),
        );
        return await _session(credential.user);
      });

  @override
  Future<void> signOut() => _auth.signOut();

  Future<Result<T>> _attempt<T>(Future<Result<T>> Function() call) async {
    try {
      return await call();
    } on FirebaseAuthException catch (error) {
      return Err<T>(
        TransportFailure(firebaseErrorCopy(error.code, error.message)),
      );
    }
  }

  Future<Result<AuthSession>> _session(User? user) async {
    final token = await user?.getIdToken();
    if (user == null || token == null) {
      return const Err<AuthSession>(
        ContractFailure('user', 'a signed-in user with an ID token'),
      );
    }
    return Ok<AuthSession>(
      AuthSession(token: token, provider: 'firebase', email: user.email),
    );
  }
}
