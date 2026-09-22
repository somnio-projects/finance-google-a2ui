import 'dart:async';
import 'dart:convert';

import 'package:finance_api_client/src/a2a_envelope.dart';
import 'package:finance_api_client/src/auth_token_provider.dart';
import 'package:finance_api_client/src/event_stream.dart';
import 'package:finance_core/finance_core.dart';
import 'package:http/http.dart' as http;

/// Speaks A2A to the agent: JSON-RPC posted to the service **root**.
///
/// Separate from `FinanceApiClient` because the two surfaces answer
/// differently and deliberately so (ADR-J D-3): `/v1/**` returns a JSON body
/// and RFC 9457 problems, while this one returns an **event stream** and
/// reports some failures at HTTP 200. Keeping them apart is what stops the
/// REST client growing a streaming branch it would take on every call.
class A2aClient {
  /// Creates a client against [baseUrl] — the service root, not `/v1`.
  A2aClient({
    required Uri baseUrl,
    required http.Client httpClient,
    required AuthTokenProvider tokenProvider,
  }) : _baseUrl = baseUrl,
       _httpClient = httpClient,
       _tokenProvider = tokenProvider;

  /// The A2UI extension this client negotiates, echoed on every turn.
  ///
  /// **This backend never reads it** — nothing under `backend/src/app/api/`
  /// or `services/` inspects the header. It is sent because spec
  /// `client/0003` AC-1 requires it and because the *protocol* defines it, not
  /// because omitting it would degrade anything here. The "omit it and A2UI
  /// silently falls back to a text agent" warning in the older GGU-2/GGU-3
  /// notes is about genui's `A2uiAgentConnector` against the upstream sample
  /// service, and does not describe this stack.
  static const String a2uiExtension =
      'https://a2ui.org/a2a-extension/a2ui/v0.9';

  final Uri _baseUrl;
  final http.Client _httpClient;
  final AuthTokenProvider _tokenProvider;

  /// Opens one agent turn for [text] and yields its events as they arrive.
  ///
  /// The three shapes this surface can answer with are all handled here
  /// (spec `client/0003` §8.5, AC-16): a 401 RFC 9457 problem document, a
  /// JSON-RPC error object **at HTTP 200**, and an event stream. A 200 is
  /// therefore never assumed to mean success (N-12).
  ///
  /// [contextId] is echoed by the server for correlation and nothing more; it
  /// is omitted when null, which is not an error.
  Future<Result<Stream<Map<String, dynamic>>>> startTurn({
    required String messageId,
    String? text,
    String? action,
    Map<String, String> actionArgs = const <String, String>{},
    String? contextId,
    String requestId = 'req-1',
  }) async {
    // One part per turn: a sentence, or a tap (spec 0022 §3.2).
    assert(
      (text == null) != (action == null),
      'a turn is either a text or a surface action',
    );
    final part = action == null
        ? <String, dynamic>{'kind': 'text', 'text': text}
        : <String, dynamic>{
            'kind': 'data',
            'data': <String, dynamic>{'action': action, 'args': actionArgs},
          };
    final request = http.Request('POST', _baseUrl.resolve('/'))
      ..headers.addAll(await _headers())
      ..body = jsonEncode(a2aEnvelope(part, messageId, contextId, requestId));
    try {
      final response = await _httpClient.send(request);
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

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'content-type': 'application/json',
      'accept': 'text/event-stream',
      'x-a2a-extensions': a2uiExtension,
    };
    final token = await _tokenProvider();
    // The credential lives in this header and nowhere else (N-14).
    if (token != null) headers['authorization'] = 'Bearer $token';
    return headers;
  }
}
