/// Doubles for the auth seam, so a widget test can sign in without Firebase
/// or a backend: a scripted identity provider and an in-memory access
/// answer behind the real [AuthRepository].
library;

import 'dart:convert';

import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:finance_core/finance_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

/// Builds an [AuthRepository] over [identity] and a fake backend that admits
/// [provisionedEmails] and mints a preview token for them.
AuthRepository fakeAuthRepository({
  FakeIdentity? identity,
  Set<String> provisionedEmails = const <String>{'demo@somnio.dev'},
  void Function()? onSignedOut,
}) {
  String? current;
  final client = FinanceApiClient(
    baseUrl: Uri.parse('http://localhost:8000'),
    tokenProvider: () async => 'session',
    httpClient: MockClient((request) async {
      switch (request.url.path) {
        case '/v1/me/access':
          // A Google session carries no e-mail this fake can read, so the
          // registry admits it whenever anybody at all is provisioned.
          final ok = current == null
              ? provisionedEmails.isNotEmpty
              : provisionedEmails.contains(current);
          return _json(<String, dynamic>{
            'email': current,
            'provisioned': ok,
            'status': ok ? 'active' : 'requested',
            'role': ok ? 'member' : null,
            'display_name': null,
            'message': ok
                ? 'Welcome back.'
                : "This account isn't provisioned for the preview.",
          });
        case '/v1/preview-sign-ins':
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          current = body['email'] as String;
          if (!provisionedEmails.contains(current)) {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'type': 'https://errors.finance-a2ui/not-provisioned',
                'title': 'Forbidden',
                'status': 403,
                'detail': "This account isn't provisioned for the preview.",
                'instance': request.url.path,
                'request_id': 'r',
              }),
              403,
              headers: <String, String>{
                'content-type': 'application/problem+json',
              },
            );
          }
          return _json(<String, dynamic>{
            'access_token': 'minted',
            'token_type': 'Bearer',
            'expires_in': 600,
          }, status: 201);
        case '/v1/access-requests':
          return http.Response('', 202);
      }
      return http.Response('', 404);
    }),
  );
  return AuthRepository(
    identity: identity ?? FakeIdentity(),
    access: AccessGateway(apiClient: client),
    onSignedOut: onSignedOut,
  );
}

http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json'},
);

/// A client whose every answer is [status] with no body.
FinanceApiClient fakeAuthRepositoryApi({required int status}) =>
    FinanceApiClient(
      baseUrl: Uri.parse('http://localhost:8000'),
      tokenProvider: () async => null,
      httpClient: MockClient((_) async => http.Response('', status)),
    );
