// The request is built at run time on purpose — two identical `const`
// instances are one object and `==` never reaches `props`; the SSE frame is
// JSON, where a space between the strings would be a different payload.
// ignore_for_file: prefer_const_constructors
// ignore_for_file: prefer_const_literals_to_create_immutables
// ignore_for_file: missing_whitespace_between_adjacent_strings
import 'dart:convert';

import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('$AgentRepository with a surface action', () {
    test("forwards the id and its scalars as the turn's one part", () async {
      final sent = <http.Request>[];
      final repository = AgentRepository(
        a2aClient: A2aClient(
          baseUrl: Uri.parse('http://localhost:8000'),
          tokenProvider: anonymousToken,
          httpClient: MockClient.streaming((request, _) async {
            sent.add(request as http.Request);
            return http.StreamedResponse(
              Stream<List<int>>.value(
                utf8.encode(
                  'data: {"kind":"status-update",'
                  '"status":{"state":"completed"},"final":true}\n\n',
                ),
              ),
              200,
              headers: <String, String>{'content-type': 'text/event-stream'},
            );
          }),
        ),
      );
      // Built at run time on purpose, so the constructor and `props` are
      // exercised rather than folded at compile time.
      final request = SurfaceActionRequest(
        action: 'ask.suggested.v1',
        args: <String, String>{'suggestion': 'tax-lots'},
      );
      expect(
        request,
        SurfaceActionRequest(
          action: 'ask.suggested.v1',
          args: <String, String>{'suggestion': 'tax-lots'},
        ),
      );
      expect(request.props.first, 'ask.suggested.v1');

      final events = await repository
          .startTurn(action: request, messageId: 'm-9')
          .toList();

      expect(events, const <AgentEvent>[
        AgentTurnEnded(AgentTurnState.completed),
      ]);
      final body = decodeJsonObject(sent.single.body)!;
      final params = body['params'] as Map<String, dynamic>;
      final message = params['message'] as Map<String, dynamic>;
      expect(message['parts'], <Map<String, dynamic>>[
        <String, dynamic>{
          'kind': 'data',
          'data': <String, dynamic>{
            'action': 'ask.suggested.v1',
            'args': <String, String>{'suggestion': 'tax-lots'},
          },
        },
      ]);
    });
  });
}
