/// The identity half of the auth seam, faked: who the provider vouches for.
///
/// Split from `auth_fakes.dart` at the seam the real code already has —
/// `AuthRepository` joins an `IdentityProvider` (*who*) with an
/// `AccessGateway` (*whether*), and this file is the first half.
library;

import 'package:finance_auth/finance_auth.dart';
import 'package:finance_core/finance_core.dart';

/// An identity provider whose answers are set by the test.
class FakeIdentity implements IdentityProvider {
  FakeIdentity({this.isConfigured = false, this.restored});

  @override
  final bool isConfigured;
  String? restored;
  Result<AuthSession> google = const Err<AuthSession>(
    TransportFailure(googleNotConfigured),
  );
  Result<void> link = const Ok<void>(null);
  Result<AuthSession> linked = const Ok<AuthSession>(
    AuthSession(token: 'linked', provider: 'firebase', email: 'a@b.test'),
  );
  final List<String> calls = <String>[];

  @override
  Future<String?> currentToken() async => restored;

  @override
  Future<Result<AuthSession>> signInWithGoogle() async {
    calls.add('google');
    return google;
  }

  @override
  Future<Result<void>> sendEmailLink(
    String email, {
    required Uri continueUrl,
  }) async {
    calls.add('link:$email');
    return link;
  }

  @override
  bool isEmailLink(Uri link) => link.queryParameters['mode'] == 'signIn';

  @override
  Future<Result<AuthSession>> signInWithEmailLink(
    String email,
    Uri link,
  ) async {
    calls.add('linked:$email');
    return linked;
  }

  @override
  Future<void> signOut() async => calls.add('signOut');
}
