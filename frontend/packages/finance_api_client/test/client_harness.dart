import 'dart:convert';

import 'package:finance_api_client/finance_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A client wired to a scripted transport, plus the requests it made.
///
/// Shared by the request-shaping suite and the response-decoding suite so both
/// drive the same construction; a fixture that differs between two halves of a
/// class's tests is how the halves stop agreeing.
class ClientHarness {
  /// Builds a client whose transport answers with [handler].
  ClientHarness(
    Future<http.Response> Function(http.Request request) handler, {
    AuthTokenProvider tokenProvider = anonymousToken,
  }) {
    client = FinanceApiClient(
      baseUrl: Uri.parse('http://localhost:8000'),
      tokenProvider: tokenProvider,
      httpClient: MockClient((request) {
        sent.add(request);
        return handler(request);
      }),
    );
  }

  /// Every request the client issued, in order.
  final List<http.Request> sent = <http.Request>[];

  /// The client under test.
  late final FinanceApiClient client;

  /// The single request issued, failing when there was not exactly one.
  http.Request get only => sent.single;
}

/// A 200 answer carrying [body] as JSON.
http.Response jsonOk(Object body, {Map<String, String>? headers}) =>
    http.Response(
      jsonEncode(body),
      200,
      headers: <String, String>{
        'content-type': 'application/json',
        ...?headers,
      },
    );
