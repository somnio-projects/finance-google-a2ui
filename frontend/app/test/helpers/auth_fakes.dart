/// Doubles for the auth seam, so a widget test can sign in without Firebase
/// or a backend: a scripted identity provider and an in-memory access
/// answer behind the real [AuthRepository].
///
/// [FakeIdentity] lives in `fake_identity.dart` and is re-exported here, so
/// the split that keeps both files inside the 150-line budget costs no test
/// an extra import.
library;

import 'dart:convert';

import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_identity.dart';

export 'fake_identity.dart';

/// Builds an [AuthRepository] over [identity] and a fake backend that admits
/// [provisionedEmails] and mints a preview token for them.
///
/// [policy] is what `GET /v1/sign-in-policy` answers. It defaults to
/// `inviteOnly` because that is the registry this fake actually simulates —
/// it admits [provisionedEmails] and refuses everyone else. Pass `null` to
/// make the read **fail**, which is the third case the screen has to handle
/// (spec backend/0043 OD-5).
AuthRepository fakeAuthRepository({
  FakeIdentity? identity,
  Set<String> provisionedEmails = const <String>{'demo@somnio.dev'},
  void Function()? onSignedOut,
  SignInPolicy? policy = SignInPolicy.inviteOnly,
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
        case '/v1/sign-in-policy':
          if (policy == null) return http.Response('', 503);
          return _json(<String, dynamic>{
            'enrolment': policy == SignInPolicy.open
                ? SignInPolicy.openValue
                : SignInPolicy.inviteOnlyValue,
          });
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
