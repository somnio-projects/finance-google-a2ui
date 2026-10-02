import 'dart:async';
import 'dart:convert';

import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// A repository whose SSE body emits [frames] and then fails.
///
/// The failure is raised **on the byte stream**, which is the shape the real
/// world produces and the one the code under test did not handle: a reset
/// connection, an SSE the edge closed, a read timeout after the response
/// headers arrived. `A2aClient` cannot catch it — it guards `send()` and the
/// response's interpretation, and by the time these bytes flow it has already
/// returned `Ok(stream)`.
AgentRepository _repositoryThatFailsMidStream(
  List<String> frames,
  Object failure,
) => AgentRepository(
  a2aClient: A2aClient(
    baseUrl: Uri.parse('http://localhost:8000'),
    catalogIds: const <String>['https://example.test/catalog.json'],
    tokenProvider: anonymousToken,
    httpClient: MockClient.streaming((_, _) async {
      final controller = StreamController<List<int>>();
      for (final frame in frames) {
        controller.add(utf8.encode(frame));
      }
      controller.addError(failure);
      unawaited(controller.close());
      return http.StreamedResponse(
        controller.stream,
        200,
        headers: <String, String>{'content-type': 'text/event-stream'},
      );
    }),
  ),
);

void main() {
  group('$AgentRepository when the stream itself fails', () {
    test('reports it as an event instead of throwing', () async {
      final repository = _repositoryThatFailsMidStream(
        <String>[],
        const SocketException('reset'),
      );

      final events = await repository
          .startTurn(text: 'what moved my portfolio today?', messageId: 'm-1')
          .toList();

      expect(events, const <AgentEvent>[
        AgentFailed(
          code: 'transport-unavailable',
          message: 'the agent stopped answering',
        ),
      ]);
    });

    test('keeps the events that arrived before it', () async {
      final repository = _repositoryThatFailsMidStream(<String>[
        'data: {"kind":"status-update","status":{"state":"working"}}\n\n',
      ], const SocketException('reset'));

      final events = await repository
          .startTurn(text: 'what moved my portfolio today?', messageId: 'm-2')
          .toList();

      // The whole point of reporting rather than throwing: a turn can fail
      // AFTER it has produced surfaces, and what arrived stays on screen.
      expect(events.length, 2);
      expect(events.last, isA<AgentFailed>());
    });

    test('never lets the transport text reach the message', () async {
      // On `BrowserClient` an exception's message carries the target URL
      // (N-14). The sentence is ours and fixed, whatever was raised.
      final repository = _repositoryThatFailsMidStream(
        <String>[],
        const SocketException('http://localhost:8000/ went away'),
      );

      final events = await repository
          .startTurn(text: 'anything', messageId: 'm-3')
          .toList();

      final failure = events.single as AgentFailed;
      expect(failure.message, isNot(contains('localhost')));
      expect(failure.message, 'the agent stopped answering');
    });

    test('catches a raised object that is not an Exception', () async {
      // `on Object`, not `on Exception`: a clause narrow enough to miss one
      // transport's choice would restore the hang for that transport.
      final repository = _repositoryThatFailsMidStream(<String>[], 'a string');

      final events = await repository
          .startTurn(text: 'anything', messageId: 'm-4')
          .toList();

      expect(events.single, isA<AgentFailed>());
    });
  });
}

/// The narrowest stand-in for a dropped connection that needs no `dart:io`,
/// which a pure-Dart package may not import in a web-targeting workspace.
class SocketException implements Exception {
  const SocketException(this.message);

  final String message;

  @override
  String toString() => 'SocketException: $message';
}
