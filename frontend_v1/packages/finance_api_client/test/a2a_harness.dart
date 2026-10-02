import 'dart:convert';

import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_core/finance_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// An [A2aClient] wired to a scripted streaming transport.
///
/// Shared by the turn suite and the failure suite so both drive the same
/// construction, and so neither opens a socket.
class A2aHarness {
  /// Builds a client whose transport answers with [respond].
  A2aHarness(
    Future<http.StreamedResponse> Function(http.BaseRequest request) respond, {
    AuthTokenProvider tokenProvider = anonymousToken,
  }) {
    client = A2aClient(
      baseUrl: Uri.parse('http://localhost:8000'),
      tokenProvider: tokenProvider,
      catalogIds: const <String>[testCatalogId],
      httpClient: MockClient.streaming((request, _) {
        sent.add(request);
        return respond(request);
      }),
    );
  }

  /// Every request the transport saw, in order.
  final List<http.BaseRequest> sent = <http.BaseRequest>[];

  /// The client under test.
  late final A2aClient client;

  /// The decoded JSON-RPC envelope of the only request made.
  Map<String, dynamic> get envelope =>
      decodeJsonObject((sent.single as http.Request).body)!;

  /// Opens a turn with fixed, uninteresting arguments.
  Future<Result<Stream<Map<String, dynamic>>>> start({String? contextId}) =>
      client.startTurn(
        text: 'What moved my portfolio this month?',
        messageId: 'm-1',
        contextId: contextId,
      );
}

/// The catalog every harness client advertises.
const String testCatalogId = 'https://example.test/catalog.json';

/// A 200 answering `text/event-stream` with [body].
http.StreamedResponse eventStream(String body) => http.StreamedResponse(
  Stream<List<int>>.value(utf8.encode(body)),
  200,
  headers: <String, String>{
    'content-type': 'text/event-stream; charset=utf-8',
    'cache-control': 'no-store',
  },
);

/// A JSON answer at [status] carrying [body].
http.StreamedResponse jsonBody(String body, {int status = 200}) =>
    http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

/// A happy-path transcript in the shape spec `backend/0053` §3 streams.
///
/// Each continuation begins after a `,` or `:` and the break carries a space,
/// which is insignificant everywhere JSON allows it — the frames stay byte-
/// equivalent to the captured ones, and the lines stay inside the budget.
const String capturedTurn =
    'data: {"kind":"status-update","status":{"state":"working"}, '
    '"final":false}\n\n'
    'data: {"kind":"artifact-update","taskId":"t","artifact": '
    '{"artifactId":"a","parts":[]}}\n\n'
    'data: {"kind":"message","role":"agent","parts":[{"kind":"text", '
    '"text":"BTC is the biggest contributor."}]}\n\n'
    'data: {"kind":"status-update","status":{"state":"input_required"}, '
    '"final":true}\n\n';
