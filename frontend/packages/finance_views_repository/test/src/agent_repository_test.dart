import 'dart:convert';

import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// A repository whose transport replays [body] as an event stream.
AgentRepository repositoryReplaying(String body, {int status = 200}) {
  final isStream = status == 200;
  return AgentRepository(
    a2aClient: A2aClient(
      baseUrl: Uri.parse('http://localhost:8000'),
      tokenProvider: anonymousToken,
      httpClient: MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode(body)),
          status,
          headers: <String, String>{
            'content-type': isStream
                ? 'text/event-stream'
                : 'application/json',
          },
        ),
      ),
    ),
  );
}

/// Runs one turn and collects every event it produced.
Future<List<AgentEvent>> run(AgentRepository repository) =>
    repository.startTurn(text: 'what moved?', messageId: 'm-1').toList();

void main() {
  group('$AgentRepository', () {
    test('reports the captured turn as typed events, in order', () async {
      // The transcript from spec client/0003 §8.3: working, a surface while
      // the turn is still running, the answer, then the terminal state.
      final events = await run(
        repositoryReplaying(
          'data: {"kind":"status-update","status":{"state":"working"}}\n\n'
          'data: {"kind":"render-intent","index":0,"renderIntent":'
          '{"view":"holdings.allocation.v1","options":{"top_n":5}}}\n\n'
          'data: {"kind":"message","parts":[{"kind":"text","text":"up"}],'
          '"renderIntents":[{"view":"holdings.allocation.v1"}]}\n\n'
          'data: {"kind":"status-update","status":{"state":"input_required"}}'
          '\n\n',
        ),
      );
      expect(events, hasLength(4));
      expect(events.first, isA<AgentTurnStarted>());
      expect(
        events[1],
        equals(
          const AgentSurfaceReady(
            index: 0,
            view: 'holdings.allocation.v1',
            options: <String, String>{'top_n': '5'},
          ),
        ),
      );
      expect((events[2] as AgentAnswered).text, equals('up'));
      expect(
        events.last,
        equals(const AgentTurnEnded(AgentTurnState.inputRequired)),
      );
    });

    test('emits the surface before the answer', () async {
      // ADR-K D-19 — the visible difference from a REST dashboard. If the
      // surface arrived only with the terminal message there would be no
      // first-pixel-early behaviour to speak of.
      final events = await run(
        repositoryReplaying(
          'data: {"kind":"render-intent","index":0,"renderIntent":'
          '{"view":"payoff.curve.v1"}}\n\n'
          'data: {"kind":"message","parts":[]}\n\n',
        ),
      );
      expect(events.first, isA<AgentSurfaceReady>());
      expect(events.last, isA<AgentAnswered>());
    });

    test('reads past the terminal status to the error that follows', () async {
      // Spec §8.5: the reason arrives AFTER final: true. A client that
      // stopped at the terminal event would show "failed" with no reason.
      final events = await run(
        repositoryReplaying(
          'data: {"kind":"status-update","status":{"state":"failed"}}\n\n'
          'data: {"kind":"error","code":"dependency-unavailable",'
          '"message":"model provider unavailable"}\n\n',
        ),
      );
      expect(events.first, equals(const AgentTurnEnded(AgentTurnState.failed)));
      expect(
        events.last,
        equals(
          const AgentFailed(
            code: 'dependency-unavailable',
            message: 'model provider unavailable',
          ),
        ),
      );
    });

    test('drops a frame it cannot parse and keeps the turn going', () async {
      final events = await run(
        repositoryReplaying(
          'data: {"kind":"artifact-update"}\n\n'
          'data: {"kind":"status-update","status":{"state":"completed"}}\n\n',
        ),
      );
      expect(events.single, isA<AgentTurnEnded>());
    });

    test('reports a refusal before the stream as a failure event', () async {
      // One failure path for the bloc: a 401 problem document arrives in the
      // same shape as an in-stream error.
      final events = await run(
        repositoryReplaying(
          '{"type":"https://errors.finance-a2ui/auth/invalid-token",'
          '"title":"Unauthorized","status":401,"detail":"Bad token."}',
          status: 401,
        ),
      );
      expect(
        events.single,
        equals(
          const AgentFailed(
            code: 'auth/invalid-token',
            message: 'Bad token.',
          ),
        ),
      );
    });
  });
}
