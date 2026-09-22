// Run-time construction is the point of the equality test at the bottom:
// two identical `const` instances are one object and never reach `props`.
// ignore_for_file: prefer_const_constructors
import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';
import 'conversation_harness.dart';

void main() {
  late MockAgentRepository agent;
  late MockViewsRepository views;

  const tax = Suggestion(key: 'tax-lots', label: 'Tax lots');
  const chips = <Suggestion>[
    tax,
    Suggestion(key: 'allocation', label: 'What do I hold?'),
  ];

  setUp(() {
    agent = MockAgentRepository();
    views = MockViewsRepository();
    when(
      () => agent.startTurn(
        text: any(named: 'text'),
        action: any(named: 'action'),
        messageId: any(named: 'messageId'),
        contextId: any(named: 'contextId'),
      ),
    ).thenAnswer(
      (_) => Stream<AgentEvent>.fromIterable(const <AgentEvent>[
        AgentTurnStarted(),
        AgentAnswered(text: 'ok', views: <String>[], suggestions: chips),
        AgentTurnEnded(AgentTurnState.completed),
      ]),
    );
    when(
      () => views.fetchPortfolioViews(
        portfolioId: any(named: 'portfolioId'),
        views: any(named: 'views'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => Ok<RenderedViews>(renderedViews()));
  });

  ConversationBloc build() =>
      ConversationBloc(agentRepository: agent, viewsRepository: views);

  group('$ConversationBloc and its surfaces', () {
    blocTest<ConversationBloc, ConversationState>(
      'a render intent lands as a skeleton, then the surface takes its slot',
      build: () => buildBloc(
        events: const <AgentEvent>[
          AgentTurnStarted(),
          exampleSurface,
          AgentTurnEnded(AgentTurnState.inputRequired),
        ],
      ),
      act: (bloc) => bloc.add(const ConversationMessageSent('what moved?')),
      verify: (bloc) {
        expect(bloc.state.entries, hasLength(2));
        expect(bloc.state.entries.last, isA<AgentSurface>());
        expect(bloc.state.entries.whereType<SurfacePending>(), isEmpty);
      },
    );
  });

  group('$ConversationBloc and its chips', () {
    blocTest<ConversationBloc, ConversationState>(
      'an answer stores the recommended chips; opening a turn clears them',
      build: build,
      act: (bloc) => bloc.add(const ConversationMessageSent('hi')),
      verify: (bloc) => expect(bloc.state.suggestions, chips),
      seed: () => const ConversationState(
        suggestions: <Suggestion>[Suggestion(key: 'x', label: 'stale')],
      ),
    );

    blocTest<ConversationBloc, ConversationState>(
      'a tapped chip echoes its label and sends only its key (OD-3)',
      build: build,
      act: (bloc) => bloc.add(const ConversationSuggestionTapped(tax)),
      verify: (bloc) {
        expect(bloc.state.entries.first, const UserSaid('Tax lots'));
        final sent =
            verify(
                  () => agent.startTurn(
                    action: captureAny(named: 'action'),
                    messageId: any(named: 'messageId'),
                    contextId: any(named: 'contextId'),
                  ),
                ).captured.single
                as SurfaceActionRequest;
        expect(sent.action, 'ask.suggested.v1');
        expect(sent.args, <String, String>{'suggestion': 'tax-lots'});
      },
    );

    blocTest<ConversationBloc, ConversationState>(
      "a surface's action opens a turn with no echo (OD-4)",
      build: build,
      act: (bloc) => bloc.add(
        const ConversationActionSent(
          SurfaceActionRequest(
            action: 'drill.attribution.v1',
            args: <String, String>{'driver': 'NVDA'},
          ),
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.entries.whereType<UserSaid>(), isEmpty);
        final sent =
            verify(
                  () => agent.startTurn(
                    action: captureAny(named: 'action'),
                    messageId: any(named: 'messageId'),
                    contextId: any(named: 'contextId'),
                  ),
                ).captured.single
                as SurfaceActionRequest;
        expect(sent.args, <String, String>{'driver': 'NVDA'});
      },
    );

    test('events are values', () {
      // Built at run time on purpose: two identical `const` instances are
      // the same object and `==` never reaches `props`.
      final one = ConversationSuggestionTapped(
        Suggestion(key: 'k', label: 'l'),
      );
      final two = ConversationSuggestionTapped(
        Suggestion(key: 'k', label: 'l'),
      );
      expect(one, two);
      expect(one.props, <Object?>[const Suggestion(key: 'k', label: 'l')]);
      final sent = ConversationActionSent(
        SurfaceActionRequest(action: 'a.b.v1'),
      );
      expect(sent.props, <Object?>['a.b.v1', const <String, String>{}]);
      expect(SurfacePending('x').props, <Object?>['x']);
    });
  });
}
