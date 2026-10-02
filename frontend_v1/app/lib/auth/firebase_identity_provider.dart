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

  @override
  Future<String?> currentToken() =>
      _auth.currentUser?.getIdToken() ?? Future<String?>.value();

  @override
  Future<Result<AuthSession>> signInWithGoogle() => _attempt(
    () async => await _session(
      (await _auth.signInWithPopup(GoogleAuthProvider())).user,
    ),
  );

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
      return Err<T>(TransportFailure(error.message ?? error.code));
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
