import 'package:finance_app/components/component_host.dart';
import 'package:finance_app/features/conversation/view/conversation_page.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import 'conversation_harness.dart';

void main() {
  group(ConversationPage, () {
    late MockAgentRepository agent;
    late MockViewsRepository views;

    setUp(() {
      agent = MockAgentRepository();
      views = MockViewsRepository();
      when(
        () => views.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => Ok<RenderedViews>(renderedViews()));
    });

    testWidgets('invites a question before anything has been asked', (
      tester,
    ) async {
      await pumpConversation(tester, agent: agent, views: views);
      expect(find.text('Ask about the portfolio.'), findsOneWidget);
    });

    testWidgets('answers in an interface, not only in text', (tester) async {
      // The whole point of the product, as one assertion: the agent's render
      // intent resolves through the SAME component registry a `?view=` read
      // uses, and a figure the backend formatted lands on screen verbatim.
      scriptTurn(agent, const <AgentEvent>[
        AgentTurnStarted(),
        AgentSurfaceReady(
          index: 0,
          view: 'holdings.allocation.v1',
          options: <String, String>{},
        ),
        AgentAnswered(
          text: 'Bitcoin is the largest holding.',
          views: <String>['holdings.allocation.v1'],
        ),
        AgentTurnEnded(AgentTurnState.inputRequired),
      ]);
      await pumpConversation(tester, agent: agent, views: views);
      await ask(tester, 'what moved?');

      expect(find.text('what moved?'), findsOneWidget);
      expect(find.text('Bitcoin is the largest holding.'), findsOneWidget);
      expect(find.byType(ComponentHost), findsOneWidget);
      expect(find.text(r'$482,915.20'), findsOneWidget);
      // N-4: the raw member behind that display string never reaches a label.
      expect(find.textContaining('65038.6'), findsNothing);
    });

    testWidgets('shows the backend safe code and detail on failure', (
      tester,
    ) async {
      scriptTurn(agent, const <AgentEvent>[
        AgentTurnEnded(AgentTurnState.failed),
        AgentFailed(
          code: 'dependency-unavailable',
          message: 'model provider unavailable',
        ),
      ]);
      await pumpConversation(tester, agent: agent, views: views);
      await ask(tester, 'what moved?');

      expect(find.text('model provider unavailable'), findsOneWidget);
      expect(find.text('dependency-unavailable'), findsOneWidget);
    });

    testWidgets('shows an answer with no surface as text alone', (
      tester,
    ) async {
      // GGU-65 AC-2, and it is **correct behaviour, not a failure**: when a
      // filter or a return-based ordering would make a donut misleading the
      // backend deliberately omits the render intent and answers in text. So
      // the assertion is as much about what is absent — no placeholder, no
      // error, no empty card — as about the sentence being shown.
      scriptTurn(agent, const <AgentEvent>[
        AgentTurnStarted(),
        AgentAnswered(text: 'You hold five assets.', views: <String>[]),
        AgentTurnEnded(AgentTurnState.inputRequired),
      ]);
      await pumpConversation(tester, agent: agent, views: views);
      await ask(tester, 'what do I hold?');

      expect(find.text('You hold five assets.'), findsOneWidget);
      // No placeholder and no empty card…
      expect(find.byType(ComponentHost), findsNothing);
      // …and no failure surface. `takeException` alone would not catch this:
      // the failure path in this same suite renders its code and detail as
      // ordinary `Text`, so a rendered error is invisible to it.
      expect(find.text('dependency-unavailable'), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ignores an empty message rather than opening a turn', (
      tester,
    ) async {
      scriptTurn(agent, const <AgentEvent>[]);
      await pumpConversation(tester, agent: agent, views: views);
      await ask(tester, '   ');

      verifyNever(
        () => agent.startTurn(
          text: any(named: 'text'),
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      );
    });
  });
}
