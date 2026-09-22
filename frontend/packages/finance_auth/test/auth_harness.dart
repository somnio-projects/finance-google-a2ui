/// Doubles for the auth package: a scripted identity provider and a fake
/// backend behind the real [FinanceApiClient].
library;

import 'dart:convert';

import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:finance_core/finance_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// An identity provider whose every answer is scripted.
class ScriptedIdentity implements IdentityProvider {
  ScriptedIdentity({
    this.isConfigured = true,
    this.restored,
    Result<AuthSession>? google,
    Result<void>? link,
    Result<AuthSession>? linked,
  }) : google = google ?? const Err<AuthSession>(TransportFailure('no google')),
       link = link ?? const Ok<void>(null),
       linked = linked ?? const Err<AuthSession>(TransportFailure('no link'));

  @override
  final bool isConfigured;
  String? restored;
  Result<AuthSession> google;
  Result<void> link;
  Result<AuthSession> linked;
  final List<String> calls = <String>[];
  Uri? continueUrl;

  @override
  Future<String?> currentToken() async {
    calls.add('currentToken');
    return restored;
  }

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
    this.continueUrl = continueUrl;
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

/// A backend answering the three provisioning routes from a script.
class FakeBackend {
  FakeBackend({this.provisioned = true, this.previewToken = 'minted'});

  bool provisioned;
  String? previewToken;
  int accessStatus = 200;
  int requestStatus = 202;
  final List<http.Request> requests = <http.Request>[];

  late final FinanceApiClient client = FinanceApiClient(
    baseUrl: Uri.parse('http://localhost:8000'),
    tokenProvider: () async => 'session',
    httpClient: MockClient(_handle),
  );

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    switch (request.url.path) {
      case '/v1/me/access':
        if (accessStatus != 200) return http.Response('', accessStatus);
        return _json(<String, dynamic>{
          'email': 'a@b.test',
          'provisioned': provisioned,
          'status': provisioned ? 'active' : 'requested',
          'role': provisioned ? 'member' : null,
          'display_name': null,
          'message': provisioned ? 'Welcome back.' : 'Not provisioned.',
        });
      case '/v1/preview-sign-ins':
        if (previewToken == null) return http.Response('', 403);
        return _json(<String, dynamic>{
          'access_token': previewToken,
          'token_type': 'Bearer',
          'expires_in': 600,
        }, status: 201);
      case '/v1/access-requests':
        return http.Response('', requestStatus);
    }
    return http.Response('', 404);
  }
}

http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json'},
);

const AuthSession firebaseSession = AuthSession(
  token: 'id-token',
  provider: 'firebase',
  email: 'a@b.test',
);
