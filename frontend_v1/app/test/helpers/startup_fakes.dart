/// Doubles for start-up (GGU-154, GGU-159, GGU-163): a restored provider
/// session and a `GET /v1/me/access` whose answers the test scripts, one
/// per call, behind the real [AuthRepository] and [FinanceApiClient].
library;

import 'dart:async';
import 'dart:convert';

import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_auth/finance_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_identity.dart';

/// The registry admitting the person.
http.Response admitted() => http.Response(
  jsonEncode(<String, dynamic>{
    'email': 'demo@somnio.dev',
    'provisioned': true,
    'status': 'active',
    'role': 'member',
    'display_name': 'Alex Chen',
    'message': 'Welcome back.',
  }),
  200,
  headers: <String, String>{'content-type': 'application/json'},
);

/// The backend's own rate limit: problem+json and `Retry-After`.
http.Response rateLimited({String? retryAfter = '60'}) => problem(
  429,
  'rate-limited',
  'Too many requests. Try again shortly.',
  retryAfter: retryAfter,
);

/// An RFC 9457 answer with [status] and the `type` suffix [code].
http.Response problem(
  int status,
  String code,
  String detail, {
  String? retryAfter,
}) => http.Response(
  jsonEncode(<String, dynamic>{
    'type': 'https://errors.finance-a2ui/$code',
    'title': 'Problem',
    'status': status,
    'detail': detail,
  }),
  status,
  headers: <String, String>{
    'content-type': 'application/problem+json',
    'retry-after': ?retryAfter,
  },
);

/// An [AuthRepository] with a provider session [restored] (null: nobody),
/// whose access check answers [answers] in order — the last one repeats.
///
/// An answer that throws is a dropped connection. A [Completer] in the list
/// holds that call open until the test completes it, which is how a test
/// sees the app *while* the session is being restored (GGU-163).
AuthRepository startupRepository({
  String? restored = 'restored-token',
  List<Object> answers = const <Object>[],
}) {
  var calls = 0;
  late final AuthRepository repository;
  final client = FinanceApiClient(
    baseUrl: Uri.parse('http://localhost:8000'),
    tokenProvider: () => repository.token(),
    onUnauthenticated: () => repository.handleUnauthenticated(),
    httpClient: MockClient((request) async {
      final script = answers.isEmpty ? <Object>[admitted()] : answers;
      final answer = script[calls < script.length ? calls : script.length - 1];
      calls++;
      return switch (answer) {
        final Completer<http.Response> pending => await pending.future,
        final http.Response response => response,
        _ => throw http.ClientException('dropped'),
      };
    }),
  );
  return repository = AuthRepository(
    identity: FakeIdentity(isConfigured: true, restored: restored),
    access: AccessGateway(apiClient: client),
  );
}
