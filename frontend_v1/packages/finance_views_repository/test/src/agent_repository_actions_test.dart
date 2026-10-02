// The request is built at run time on purpose — two identical `const`
// instances are one object and `==` never reaches `props`; the SSE frame is
// JSON, where a space between the strings would be a different payload.
// ignore_for_file: prefer_const_constructors
// ignore_for_file: prefer_const_literals_to_create_immutables
// ignore_for_file: missing_whitespace_between_adjacent_strings
import 'dart:convert';

import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_api_client/finance_api_client.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('$AgentRepository with A2UI messages', () {
    test("sends them as the request's one DataPart (ADR-M D-7)", () async {
      final sent = <http.Request>[];
      final repository = AgentRepository(
        a2aClient: A2aClient(
          baseUrl: Uri.parse('http://localhost:8000'),
          catalogIds: const <String>['https://example.test/catalog.json'],
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
        action: 'drill_attribution',
        args: <String, String>{'driver': 'LINK'},
      );
      expect(
        request,
        SurfaceActionRequest(
          action: 'drill_attribution',
          args: <String, String>{'driver': 'LINK'},
        ),
      );
      expect(request.props.first, 'drill_attribution');

      final events = await repository
          .startTurn(
            messages: <RendererMessage>[
              drillAttribution(
                surfaceId: 's-0',
                sourceComponentId: 'root',
                timestamp: '2026-10-01T22:00:00Z',
                driver: request.args['driver']!,
              ),
            ],
            messageId: 'm-9',
          )
          .toList();

      expect(events, const <AgentEvent>[
        AgentTurnEnded(AgentTurnState.completed),
      ]);
      final body = decodeJsonObject(sent.single.body)!;
      final params = body['params'] as Map<String, dynamic>;
      final message = params['message'] as Map<String, dynamic>;
      final parts = message['parts'] as List<dynamic>;
      expect(decodeRendererDataPart(parts.single).single, isA<ActionMessage>());
    });
  });
}
