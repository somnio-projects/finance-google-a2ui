// Run-time construction is the point of the equality test at the bottom:
// two identical `const` instances are one object and never reach `props`.
// ignore_for_file: prefer_const_constructors
import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/a2ui_fixtures.dart';
import 'conversation_harness.dart';

void main() {
  late MockAgentRepository agent;

  const tax = Suggestion(key: 'tax-lots', label: 'Tax lots');
  const chips = <Suggestion>[
    tax,
    Suggestion(key: 'allocation', label: 'What do I hold?'),
  ];

  setUp(() {
    agent = MockAgentRepository();
    scriptAgent(agent, const <AgentEvent>[
      AgentTurnStarted(),
      AgentAnswered(text: 'ok', suggestions: chips),
      AgentTurnEnded(AgentTurnState.completed),
    ]);
  });

  ConversationBloc build() => buildBloc(
    events: const <AgentEvent>[
      AgentTurnStarted(),
      AgentAnswered(text: 'ok', suggestions: chips),
      AgentTurnEnded(AgentTurnState.completed),
    ],
    agent: agent,
  );

  group('$ConversationBloc and its chips', () {
    blocTest<ConversationBloc, ConversationState>(
      'an answer replaces the chips of the answer before it',
      build: build,
      act: (bloc) => bloc.add(const ConversationMessageSent('hi')),
      verify: (bloc) => expect(bloc.state.suggestions, chips),
      seed: () => const ConversationState(
        suggestions: <Suggestion>[Suggestion(key: 'x', label: 'stale')],
      ),
    );

    blocTest<ConversationBloc, ConversationState>(
      'a tapped chip is sent as its own words in a text part (ADR-M D-7)',
      build: build,
      act: (bloc) => bloc.add(const ConversationSuggestionTapped(tax)),
      verify: (bloc) {
        expect(bloc.state.entries.first, const UserSaid('Tax lots'));
        verify(
          () => agent.startTurn(
            text: 'Tax lots',
            messageId: any(named: 'messageId'),
            contextId: any(named: 'contextId'),
          ),
        ).called(1);
      },
    );
  });

  group('$ConversationBloc and a surface action', () {
    blocTest<ConversationBloc, ConversationState>(
      'a bar tap is a v1.0 action with no echo (AC-6)',
      build: build,
      act: (bloc) => bloc.add(
        const ConversationActionSent(
          surfaceId: 'turn-4b10-0',
          componentId: 'root',
          request: SurfaceActionRequest(
            action: drillAttributionAction,
            args: <String, String>{'driver': 'LINK'},
          ),
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.entries.whereType<UserSaid>(), isEmpty);
        // The message, stamped by the fixed clock, is the canonical example.
        expect(
          encodeDataPart(sentMessages(agent)),
          v1Example('action.drill_attribution.json'),
        );
      },
    );
  });

  test('events are values', () {
    final one = ConversationSuggestionTapped(Suggestion(key: 'k', label: 'l'));
    final two = ConversationSuggestionTapped(Suggestion(key: 'k', label: 'l'));
    expect(one, two);
    expect(one.props, <Object?>[const Suggestion(key: 'k', label: 'l')]);
    final sent = ConversationActionSent(
      surfaceId: 's',
      componentId: 'c',
      request: SurfaceActionRequest(action: 'a'),
    );
    expect(sent.props, <Object?>[
      's',
      'c',
      const SurfaceActionRequest(action: 'a'),
    ]);
    expect(AgentSurface('x').props, <Object?>['x']);
    expect(SurfaceEditState(pendingOption: 'a').props, <Object?>['a', null]);
    expect(TurnRequest(text: 't').props, <Object?>['t', <RendererMessage>[]]);
  });
}
