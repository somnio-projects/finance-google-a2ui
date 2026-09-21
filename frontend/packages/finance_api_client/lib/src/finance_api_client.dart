import 'dart:async';
import 'dart:convert';

import 'package:finance_api_client/src/auth_token_provider.dart';
import 'package:finance_api_client/src/json_response.dart';
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
  }) : _baseUrl = baseUrl,
       _httpClient = httpClient,
       _tokenProvider = tokenProvider;

  final Uri _baseUrl;
  final http.Client _httpClient;
  final AuthTokenProvider _tokenProvider;

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
      return _decode(response, path);
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

  /// Releases the underlying connection pool.
  void close() => _httpClient.close();

  Uri _resolve(String path, Map<String, List<String>> query) {
    final resolved = _baseUrl.resolve(path);
    if (query.isEmpty) return resolved;
    return resolved.replace(queryParameters: query);
  }

  Future<Map<String, String>> _headers(String? ifNoneMatch) async {
    final headers = <String, String>{'accept': 'application/json'};
    final token = await _tokenProvider();
    // The credential appears here and nowhere else — never in the URI, never
    // in a log line (spec client/0003 N-14).
    if (token != null) headers['authorization'] = 'Bearer $token';
    if (ifNoneMatch != null) headers['if-none-match'] = ifNoneMatch;
    return headers;
  }

  Result<JsonResponse> _decode(http.Response response, String path) {
    final etag = response.headers['etag'];
    if (response.statusCode == 304) {
      return Ok<JsonResponse>(
        JsonResponse(statusCode: 304, body: null, etag: etag),
      );
    }
    final body = _parseBody(response);
    if (response.statusCode >= 400) return _failure(response, body);
    if (body == null) {
      return Err<JsonResponse>(
        ContractFailure(path, 'a JSON body on a ${response.statusCode}'),
      );
    }
    return Ok<JsonResponse>(
      JsonResponse(statusCode: response.statusCode, body: body, etag: etag),
    );
  }

  Object? _parseBody(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }

  Err<JsonResponse> _failure(http.Response response, Object? body) {
    final problem = ProblemDetails.tryParse(body);
    if (problem != null) return Err<JsonResponse>(ProblemFailure(problem));
    // Not a problem document: a proxy, a load balancer or a gateway answered.
    // Reporting it as a transport failure is honest; inventing a problem
    // document the backend never sent would not be.
    return Err<JsonResponse>(
      TransportFailure('the server answered ${response.statusCode}'),
    );
  }
}
