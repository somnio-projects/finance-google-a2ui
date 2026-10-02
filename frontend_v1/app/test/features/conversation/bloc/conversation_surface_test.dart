import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/a2ui_fixtures.dart';
import 'conversation_harness.dart';

/// Runs one turn to its end and returns where the bloc came to rest.
Future<ConversationState> afterTurn(List<AgentEvent> events) async {
  final bloc = buildBloc(events: events)
    ..add(const ConversationMessageSent('what moved?'));
  await bloc.stream.firstWhere(
    (state) => state.status != ConversationStatus.running,
  );
  final state = bloc.state;
  await bloc.close();
  return state;
}

void main() {
  group('$ConversationBloc A2UI surfaces', () {
    test('a createSurface joins the transcript with its data', () async {
      // ADR-M D-3: the payload is in the data model — nothing is fetched.
      final state = await afterTurn(<AgentEvent>[exampleSurface]);
      expect(state.entries.last, const AgentSurface(exampleSurfaceId));
      final surface = state.surfaces[exampleSurfaceId]!;
      expect(surface.read('/root/view'), exampleView);
      expect(surface.read('/root/options/top_n'), 5);
    });

    test('both canonical surfaces build, in arrival order', () async {
      // Spec frontend_v1/0001 AC-2, from the examples themselves.
      final state = await afterTurn(<AgentEvent>[
        v1ExampleEvent('surface.portfolio_summary.json'),
        v1ExampleEvent('surface.order_ticket_with_payoff.json'),
      ]);
      expect(state.entries.whereType<AgentSurface>(), const <AgentSurface>[
        AgentSurface('turn-7f3a-0'),
        AgentSurface('turn-9c21-0'),
      ]);
      expect(
        state.surfaces['turn-9c21-0']!.components['root']!.children,
        <String>['payoff'],
      );
    });

    test('a later updateDataModel re-renders the same entry', () async {
      final state = await afterTurn(<AgentEvent>[
        v1ExampleEvent('surface.portfolio_summary.json'),
        v1ExampleEvent('agent_function_response.render_view.json'),
      ]);
      expect(state.entries.whereType<AgentSurface>(), hasLength(1));
      expect(state.surfaces['turn-7f3a-0']!.read('/root/options/range'), '1y');
    });

    test('a deleteSurface takes its entry with it', () async {
      final state = await afterTurn(<AgentEvent>[
        exampleSurface,
        const AgentSurfaceMessages(<Decoded>[
          DecodedMessage(DeleteSurface(exampleSurfaceId)),
        ]),
      ]);
      expect(state.entries.whereType<AgentSurface>(), isEmpty);
      expect(state.surfaces.surfaces, isEmpty);
    });

    test('a message that cannot apply is recorded, the rest still do', () {
      // The extension spec's processing rules: report, then carry on.
      return afterTurn(<AgentEvent>[
        const AgentSurfaceMessages(<Decoded>[
          DecodedMessage(DeleteSurface('never-created')),
        ]),
        exampleSurface,
      ]).then((state) {
        expect(state.rendererErrors.single.code, 'SURFACE_NOT_FOUND');
        expect(state.entries.last, const AgentSurface(exampleSurfaceId));
      });
    });
  });
}
