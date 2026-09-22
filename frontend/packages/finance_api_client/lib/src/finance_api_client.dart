import 'dart:async';
import 'dart:convert';

import 'package:finance_api_client/src/auth_token_provider.dart';
import 'package:finance_api_client/src/json_response.dart';
import 'package:finance_api_client/src/response_decoder.dart';
import 'package:finance_core/finance_core.dart';
import 'package:http/http.dart' as http;

/// Talks JSON to the finance backend over HTTP.
///
/// Everything it can go wrong with is a [Result], not an exception: a socket
/// error, a problem document and an unreadable body all arrive at the caller
/// as an [AppFailure]. Nothing above this class handles an `http` type.
class FinanceApiClient {
  /// Creates a client against [baseUrl].
  ///
  /// [httpClient] is injected so tests drive the transport with
  /// `http.testing.MockClient` and never open a socket; [tokenProvider] is
  /// consulted once per request so a refreshed credential is picked up without
  /// rebuilding anything.
  FinanceApiClient({
    required Uri baseUrl,
    required http.Client httpClient,
    required AuthTokenProvider tokenProvider,
    void Function()? onUnauthenticated,
  }) : _baseUrl = baseUrl,
       _httpClient = httpClient,
       _tokenProvider = tokenProvider,
       _onUnauthenticated = onUnauthenticated;

  final Uri _baseUrl;
  final http.Client _httpClient;
  final AuthTokenProvider _tokenProvider;

  /// Told once per 401 on an authenticated call — the session is over and
  /// the shell must close (ADR-B D-7: no retry loop, sign out). Null when
  /// nobody is listening, which is what the tests and the tools want.
  final void Function()? _onUnauthenticated;

  /// Issues `GET [path]` and decodes a JSON body.
  ///
  /// [query] may repeat a key — that is how several `view` parameters travel
  /// in one request. [ifNoneMatch] is an `ETag` from a previous response,
  /// passed back verbatim; a 304 comes back as a successful [JsonResponse]
  /// with no body.
  Future<Result<JsonResponse>> getJson(
    String path, {
    Map<String, List<String>> query = const <String, List<String>>{},
    String? ifNoneMatch,
  }) async {
    final uri = _resolve(path, query);
    final headers = await _headers(ifNoneMatch);
    try {
      final response = await _httpClient.get(uri, headers: headers);
      return decodeJsonResponse(
        response,
        onUnauthenticated: _onUnauthenticated,
      );
    } on http.ClientException {
      // Deliberately NOT `error.message`. That string is package:http's
      // own, and on BrowserClient it carries the target URL — neither is
      // ours to show a user (SECURITY.md, N-14). The failure kind is what
      // a caller branches on; the wording is ours.
      return const Err<JsonResponse>(
        TransportFailure('the server could not be reached'),
      );
    } on TimeoutException {
      return const Err<JsonResponse>(TransportFailure('the request timed out'));
    }
  }

  /// `POST`s [body] as JSON to [path] and decodes the answer like [getJson].
  ///
  /// [authenticated] is false for the two routes a person reaches *before*
  /// they have a token (spec backend/0027): no `Authorization` header is
  /// sent, and a 401 there is an answer, not the end of a session.
  Future<Result<JsonResponse>> postJson(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    final headers = await _headers(null, authenticated: authenticated);
    headers['content-type'] = 'application/json';
    try {
      final response = await _httpClient.post(
        _resolve(path, const <String, List<String>>{}),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
      return decodeJsonResponse(
        response,
        authenticated: authenticated,
        onUnauthenticated: _onUnauthenticated,
      );
    } on http.ClientException {
      return const Err<JsonResponse>(
        TransportFailure('the server could not be reached'),
      );
    } on TimeoutException {
      return const Err<JsonResponse>(TransportFailure('the request timed out'));
    }
  }

  /// Releases the underlying connection pool.
  void close() => _httpClient.close();

  Uri _resolve(String path, Map<String, List<String>> query) {
    final resolved = _baseUrl.resolve(path);
    if (query.isEmpty) return resolved;
    return resolved.replace(queryParameters: query);
  }

  Future<Map<String, String>> _headers(
    String? ifNoneMatch, {
    bool authenticated = true,
  }) async {
    final headers = <String, String>{'accept': 'application/json'};
    final token = authenticated ? await _tokenProvider() : null;
    // The credential appears here and nowhere else — never in the URI, never
    // in a log line (spec client/0003 N-14).
    if (token != null) headers['authorization'] = 'Bearer $token';
    if (ifNoneMatch != null) headers['if-none-match'] = ifNoneMatch;
    return headers;
  }
}
