import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'conversation_harness.dart';

void main() {
  group(ConversationBloc, () {
    blocTest<ConversationBloc, ConversationState>(
      'shows the question, then the surface, then the answer',
      // The order is the point: the surface is appended when the intent
      // lands, before the answer text (ADR-K D-19).
      build: () => buildBloc(
        events: const <AgentEvent>[
          AgentTurnStarted(),
          exampleSurface,
          AgentAnswered(text: 'NVDA led it.', views: <String>[exampleView]),
          AgentTurnEnded(AgentTurnState.inputRequired),
        ],
      ),
      act: (bloc) => bloc.add(const ConversationMessageSent('what moved?')),
      verify: (bloc) {
        expect(bloc.state.entries, hasLength(3));
        expect(bloc.state.entries[0], equals(const UserSaid('what moved?')));
        expect(bloc.state.entries[1], isA<AgentSurface>());
        expect(bloc.state.entries[2], equals(const AgentSaid('NVDA led it.')));
        expect(bloc.state.status, equals(ConversationStatus.idle));
      },
    );

    blocTest<ConversationBloc, ConversationState>(
      'treats input_required as a success, not a failure',
      // N-11 / ADR-D D-3 — the state a widget-bearing turn ends in.
      build: () => buildBloc(
        events: const <AgentEvent>[
          AgentTurnEnded(AgentTurnState.inputRequired),
        ],
      ),
      act: (bloc) => bloc.add(const ConversationMessageSent('hello')),
      verify: (bloc) {
        expect(bloc.state.status, equals(ConversationStatus.idle));
        expect(bloc.state.failure, isNull);
      },
    );

    blocTest<ConversationBloc, ConversationState>(
      'treats completed as a success too',
      build: () => buildBloc(
        events: const <AgentEvent>[AgentTurnEnded(AgentTurnState.completed)],
      ),
      act: (bloc) => bloc.add(const ConversationMessageSent('hello')),
      verify: (bloc) =>
          expect(bloc.state.status, equals(ConversationStatus.idle)),
    );

    blocTest<ConversationBloc, ConversationState>(
      'keeps the reason that arrives after the terminal status',
      // Spec client/0003 §8.5: the error event follows final: true.
      build: () => buildBloc(
        events: const <AgentEvent>[
          AgentTurnEnded(AgentTurnState.failed),
          AgentFailed(
            code: 'dependency-unavailable',
            message: 'model provider unavailable',
          ),
        ],
      ),
      act: (bloc) => bloc.add(const ConversationMessageSent('hello')),
      verify: (bloc) {
        expect(bloc.state.status, equals(ConversationStatus.failed));
        expect(bloc.state.failure?.code, equals('dependency-unavailable'));
        expect(
          bloc.state.failure?.message,
          equals('model provider unavailable'),
        );
      },
    );
  });
}
