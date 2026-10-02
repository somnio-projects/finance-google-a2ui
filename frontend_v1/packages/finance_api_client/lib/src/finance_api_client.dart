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
/// error, a problem document, an unreadable body, a stalled connection and a
/// credential that could not be read all arrive at the caller as an
/// [AppFailure]. Nothing above this class handles an `http` type.
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
    this.timeout = defaultTimeout,
  }) : _baseUrl = baseUrl,
       _httpClient = httpClient,
       _tokenProvider = tokenProvider,
       _onUnauthenticated = onUnauthenticated;

  /// How long one request may take before it is reported as timed out.
  ///
  /// The browser's own limit is minutes, and a skeleton is drawn until the
  /// request settles — so with none of our own a stalled connection was a
  /// screen loading forever with nothing to say (GGU-110 AC-3). Twenty
  /// seconds is past the backend's cold start and short of anyone's patience.
  static const Duration defaultTimeout = Duration(seconds: 20);

  /// The limit in force; a test injects a short one.
  final Duration timeout;

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
  ///
  /// [authenticated] is false for a route a person reaches *before* they have
  /// a token — the same allowance [postJson] already makes, for the same
  /// reason (spec backend/0043): no `Authorization` header is sent, and a 401
  /// there is an answer rather than the end of a session.
  Future<Result<JsonResponse>> getJson(
    String path, {
    Map<String, List<String>> query = const <String, List<String>>{},
    String? ifNoneMatch,
    bool authenticated = true,
  }) => _send(
    (headers) => _httpClient.get(_resolve(path, query), headers: headers),
    authenticated: authenticated,
    ifNoneMatch: ifNoneMatch,
  );

  /// `POST`s [body] as JSON to [path] and decodes the answer like [getJson].
  ///
  /// [authenticated] is false for the routes a person reaches *before* they
  /// have a token (spec backend/0027): no `Authorization` header is sent, and
  /// a 401 there is an answer, not the end of a session.
  Future<Result<JsonResponse>> postJson(
    String path, {
    Object? body,
    bool authenticated = true,
  }) => _send(
    (headers) => _httpClient.post(
      _resolve(path, const <String, List<String>>{}),
      headers: <String, String>{...headers, 'content-type': 'application/json'},
      body: body == null ? null : jsonEncode(body),
    ),
    authenticated: authenticated,
  );

  /// Releases the underlying connection pool.
  void close() => _httpClient.close();

  /// One request, every failure a value. The credential is read **inside**
  /// the guard: the provider is an identity SDK refreshing over the network,
  /// and a refresh that threw used to escape this class as an exception and
  /// leave the asking screen on its skeleton (GGU-110). Bounded by [timeout].
  Future<Result<JsonResponse>> _send(
    Future<http.Response> Function(Map<String, String> headers) request, {
    required bool authenticated,
    String? ifNoneMatch,
  }) async {
    final String? token;
    try {
      token = authenticated ? await _tokenProvider() : null;
    } on Object {
      return const Err<JsonResponse>(TransportFailure(credentialUnavailable));
    }
    try {
      final response = await request(_headers(token, ifNoneMatch))
          .timeout(timeout);
      return decodeJsonResponse(
        response,
        authenticated: authenticated,
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

  Uri _resolve(String path, Map<String, List<String>> query) {
    final resolved = _baseUrl.resolve(path);
    if (query.isEmpty) return resolved;
    return resolved.replace(queryParameters: query);
  }

  /// The credential appears here and nowhere else — never in the URI, never
  /// in a log line (spec client/0003 N-14).
  Map<String, String> _headers(String? token, String? ifNoneMatch) => {
    'accept': 'application/json',
    if (token case final token?) 'authorization': 'Bearer $token',
    'if-none-match': ?ifNoneMatch,
  };
}
