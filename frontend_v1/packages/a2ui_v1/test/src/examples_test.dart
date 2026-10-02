import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:test/test.dart';

import '../helpers/examples.dart';

/// Spec `frontend_v1/0001` AC-1: every canonical example parses, and the
/// renderer-to-agent ones round-trip JSON-equal.
void main() {
  group('every file in docs/a2ui/v1.0/examples', () {
    for (final name in exampleNames()) {
      test('$name is an A2UI DataPart', () {
        expect(isA2uiDataPart(example(name)), isTrue);
      });

      if (isRendererToAgent(name)) {
        test('$name round-trips JSON-equal', () {
          final part = example(name);
          final messages = decodeRendererDataPart(part);
          expect(messages, isNotEmpty);
          expect(encodeDataPart(messages), equals(part));
        });
      } else {
        test('$name decodes with no failure', () {
          expect(agentMessages(name), isNotEmpty);
        });
      }
    }
  });

  group('the builders produce the canonical examples', () {
    test('renderViewCall is call_agent_function.render_view.json', () {
      final call = renderViewCall(
        surfaceId: 'turn-7f3a-0',
        functionCallId: 'call-01',
        catalogId: 'https://somniosoftware.com/a2ui/finance-showcase/v1.0/catalog.json',
        componentId: 'root',
        view: 'portfolio.summary.v1',
        options: const <String, Object?>{'range': '1y'},
      );
      expect(
        encodeDataPart(<RendererMessage>[call]),
        equals(example('call_agent_function.render_view.json')),
      );
    });

    test('drillAttribution is action.drill_attribution.json', () {
      final action = drillAttribution(
        surfaceId: 'turn-4b10-0',
        sourceComponentId: 'root',
        timestamp: '2026-10-01T22:00:00Z',
        driver: 'LINK',
      );
      expect(
        encodeDataPart(<RendererMessage>[action]),
        equals(example('action.drill_attribution.json')),
      );
    });
  });

  group('the agent-to-renderer examples decode to', () {
    test('a function response and a data model update', () {
      final messages = agentMessages(
        'agent_function_response.render_view.json',
      );
      final response = messages.first as AgentFunctionResponse;
      expect(response.functionCallId, 'call-01');
      expect(response.error, isNull);
      expect(response.value, <String, Object?>{
        'componentId': 'root',
        'view': 'portfolio.summary.v1',
      });
      final update = messages.last as UpdateDataModel;
      expect(update.path, '/root');
      expect(update.surfaceId, 'turn-7f3a-0');
    });

    test('a refused call with its code', () {
      final response =
          agentMessages('agent_function_response.invalid.json').single
              as AgentFunctionResponse;
      expect(response.error?.code, 'INVALID_FUNCTION_CALL');
      expect(response.error?.message, contains("'range'"));
    });

    test('a ticket with its payoff child', () {
      final create =
          agentMessages('surface.order_ticket_with_payoff.json').single
              as CreateSurface;
      expect(create.components.map((node) => node.id), <String>[
        'root',
        'payoff',
      ]);
      expect(create.components.first.children, <String>['payoff']);
      expect(create.components.last.dataPath, '/payoff');
      expect(create.dataModel.keys, containsAll(<String>['root', 'payoff']));
    });
  });
}
