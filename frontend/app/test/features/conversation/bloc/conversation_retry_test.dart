import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'conversation_harness.dart';

/// GGU-111: a failed turn left a red code on screen, no chips and no way to
/// send the question again.
void main() {
  const chips = <Suggestion>[Suggestion(key: 'drivers', label: 'Drivers')];
  const failed = <AgentEvent>[
    AgentTurnEnded(AgentTurnState.failed),
    AgentFailed(
      code: 'dependency-unavailable',
      message: 'model provider unavailable',
    ),
  ];

  group('$ConversationBloc after a failed turn', () {
    blocTest<ConversationBloc, ConversationState>(
      "keeps the last answer's chips (AC-2) and remembers what was sent",
      build: () => buildBloc(events: failed),
      seed: () => const ConversationState(suggestions: chips),
      act: (bloc) => bloc.add(const ConversationMessageSent('what moved?')),
      verify: (bloc) {
        expect(bloc.state.status, ConversationStatus.failed);
        expect(bloc.state.suggestions, chips);
        expect(bloc.state.lastTurn, const TurnRequest(text: 'what moved?'));
        expect(bloc.state.entries, const <ConversationEntry>[
          UserSaid('what moved?'),
        ]);
      },
    );

    test(
      'Try again sends the same sentence and echoes nothing (AC-1)',
      () async {
        final agent = MockAgentRepository();
        when(
          () => agent.startTurn(
            text: any(named: 'text'),
            action: any(named: 'action'),
            messageId: any(named: 'messageId'),
            contextId: any(named: 'contextId'),
          ),
        ).thenAnswer((_) => Stream<AgentEvent>.fromIterable(failed));
        final bloc = ConversationBloc(
          agentRepository: agent,
          viewsRepository: MockViewsRepository(),
        )..add(const ConversationMessageSent('what moved?'));
        // On the reason, not the status: the status turns `failed` one event
        // before the reason lands, and a retry sent in that gap would race
        // the first turn's last emission.
        await bloc.stream.firstWhere((s) => s.failure != null);
        // The answer arrives this time.
        when(
          () => agent.startTurn(
            text: any(named: 'text'),
            action: any(named: 'action'),
            messageId: any(named: 'messageId'),
            contextId: any(named: 'contextId'),
          ),
        ).thenAnswer(
          (_) => Stream<AgentEvent>.fromIterable(const <AgentEvent>[
            AgentAnswered(
              text: 'BTC led.',
              views: <String>[],
              suggestions: chips,
            ),
            AgentTurnEnded(AgentTurnState.completed),
          ]),
        );

        bloc.add(const ConversationRetried());
        await bloc.stream.firstWhere(
          (s) => s.status == ConversationStatus.idle,
        );

        verify(
          () => agent.startTurn(
            text: 'what moved?',
            action: any(named: 'action'),
            messageId: any(named: 'messageId'),
            contextId: any(named: 'contextId'),
          ),
        ).called(2);
        // One bubble, not two: the question is already in the transcript.
        expect(bloc.state.entries, const <ConversationEntry>[
          UserSaid('what moved?'),
          AgentSaid('BTC led.'),
        ]);
        expect(bloc.state.failure, isNull);
        expect(bloc.state.suggestions, chips);
        await bloc.close();
      },
    );

    blocTest<ConversationBloc, ConversationState>(
      'Try again with nothing to repeat does nothing',
      build: () => buildBloc(events: failed),
      act: (bloc) => bloc.add(const ConversationRetried()),
      expect: () => <ConversationState>[],
    );
  });
}
