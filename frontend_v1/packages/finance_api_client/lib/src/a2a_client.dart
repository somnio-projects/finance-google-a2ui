import 'dart:async';
import 'dart:convert';

import 'package:finance_api_client/src/a2a_envelope.dart';
import 'package:finance_api_client/src/auth_token_provider.dart';
import 'package:finance_api_client/src/event_stream.dart';
import 'package:finance_api_client/src/finance_api_client.dart';
import 'package:finance_core/finance_core.dart';
import 'package:http/http.dart' as http;

/// Speaks A2A to the A2UI **v1.0** agent: JSON-RPC posted to
/// `/a2ui/v1/a2a` (spec `backend/0053` §3, ADR-M D-2).
///
/// Separate from `FinanceApiClient` (ADR-J D-3): this surface answers with
/// an **event stream** and reports some failures at HTTP 200. `frontend/`
/// keeps v0.9 on `POST /`; only route, extension and metadata differ here.
class A2aClient {
  /// Creates a client against [baseUrl] — the service root, not `/v1` —
  /// advertising [catalogIds] as the catalogs this renderer supports.
  A2aClient({
    required Uri baseUrl,
    required http.Client httpClient,
    required AuthTokenProvider tokenProvider,
    required List<String> catalogIds,
    this.timeout = FinanceApiClient.defaultTimeout,
  }) : _baseUrl = baseUrl,
       _httpClient = httpClient,
       _tokenProvider = tokenProvider,
       _catalogIds = catalogIds;

  /// How long the open may take — headers back, not the stream (GGU-110).
  final Duration timeout;

  /// The route every turn and every function call is posted to.
  static const String endpoint = '/a2ui/v1/a2a';

  /// The A2UI extension this client activates, on every request (ADR-M D-8).
  static const String a2uiExtension =
      'https://a2ui.org/a2a-extension/a2ui/v1.0';

  final Uri _baseUrl;
  final http.Client _httpClient;
  final AuthTokenProvider _tokenProvider;
  final List<String> _catalogIds;

  /// Opens one request — a sentence in [text], or A2UI messages in
  /// [dataPart] — and yields its events as they arrive.
  ///
  /// Three answers are handled (spec `client/0003` §8.5): a 401 problem
  /// document, a JSON-RPC error **at HTTP 200** (also how the agent refuses
  /// a renderer lacking its catalog, ADR-M D-8), and an event stream (N-12).
  ///
  /// [contextId] is echoed by the server for correlation and nothing more; it
  /// is omitted when null, which is not an error.
  Future<Result<Stream<Map<String, dynamic>>>> startTurn({
    required String messageId,
    String? text,
    Map<String, dynamic>? dataPart,
    String? contextId,
    String requestId = 'req-1',
  }) async {
    // One part per request: a sentence, or A2UI messages (ADR-M D-6, D-7).
    assert(
      (text == null) != (dataPart == null),
      'a request is either a text or an A2UI DataPart',
    );
    final part = dataPart ?? <String, dynamic>{'kind': 'text', 'text': text};
    final String? token;
    try {
      token = await _tokenProvider();
    } on Object {
      return const Err<Stream<Map<String, dynamic>>>(
        TransportFailure(credentialUnavailable),
      );
    }
    final request = http.Request('POST', _baseUrl.resolve(endpoint))
      ..headers.addAll(_headers(token))
      ..body = jsonEncode(
        a2aEnvelope(
          part,
          messageId,
          contextId,
          requestId,
          metadata: rendererMetadata(_catalogIds),
        ),
      );
    try {
      final response = await _httpClient.send(request).timeout(timeout);
      return await _interpret(response);
    } on http.ClientException {
      // Never `error.message`: on BrowserClient it carries the target URL,
      // which is not ours to show a user (N-14).
      return const Err<Stream<Map<String, dynamic>>>(
        TransportFailure('the agent could not be reached'),
      );
    } on TimeoutException {
      return const Err<Stream<Map<String, dynamic>>>(
        TransportFailure('the agent timed out'),
      );
    }
  }

  Future<Result<Stream<Map<String, dynamic>>>> _interpret(
    http.StreamedResponse response,
  ) async {
    if (response.statusCode >= 400) {
      // A failure *before* the envelope is parsed is an ordinary problem
      // document at its real status — unauthenticated, rate limited, or the
      // `agent.a2a` kill-switch answering 404.
      final body = await response.stream.bytesToString();
      final problem = ProblemDetails.tryParse(decodeJsonObject(body));
      if (problem != null) {
        return Err<Stream<Map<String, dynamic>>>(ProblemFailure(problem));
      }
      return Err<Stream<Map<String, dynamic>>>(
        TransportFailure('the agent answered ${response.statusCode}'),
      );
    }
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.contains('text/event-stream')) {
      return Ok<Stream<Map<String, dynamic>>>(
        decodeEventStream(response.stream),
      );
    }
    // HTTP 200 carrying JSON: a JSON-RPC error object for an unknown or
    // unsupported method. Its `message` is a fixed, safe string the server
    // owns, so it is shown rather than replaced.
    final body = await response.stream.bytesToString();
    return Err<Stream<Map<String, dynamic>>>(
      TransportFailure(_rpcMessage(decodeJsonObject(body))),
    );
  }

  String _rpcMessage(Map<String, dynamic>? body) {
    final error = body?['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String) return message;
    }
    return 'the agent refused the request';
  }

  Map<String, String> _headers(String? token) => <String, String>{
    'content-type': 'application/json',
    'accept': 'text/event-stream',
    'x-a2a-extensions': a2uiExtension,
    // The credential lives in this header and nowhere else (N-14).
    if (token != null) 'authorization': 'Bearer $token',
  };
}
