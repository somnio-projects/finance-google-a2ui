import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/components/component_host.dart';
import 'package:finance_app/features/conversation/view/conversation_page.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';

class _MockAgentRepository extends Mock implements AgentRepository;

class _MockViewsRepository extends Mock implements ViewsRepository;

void main() {
  group(ConversationPage, () {
    late _MockAgentRepository agent;
    late _MockViewsRepository views;

    setUp(() {
      agent = _MockAgentRepository();
      views = _MockViewsRepository();
      when(
        () => views.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => Ok<RenderedViews>(renderedViews()));
    });

    void scriptTurn(List<AgentEvent> events) {
      when(
        () => agent.startTurn(
          text: any(named: 'text'),
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      ).thenAnswer((_) => Stream<AgentEvent>.fromIterable(events));
    }

    Future<void> pump(WidgetTester tester) {
      // A taller surface than the 800x600 default, because the transcript is
      // a lazy `ListView`: with a full-height surface card in the middle, the
      // answer that follows it is never built and `find.text` cannot see a
      // widget that does not exist. This is a test-harness fact, not a
      // product one — nothing in the app depends on the window size.
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      return tester.pumpApp(
        const ConversationPage(),
        viewsRepository: views,
        agentRepository: agent,
        componentRegistry: buildComponentRegistry(),
      );
    }

    Future<void> ask(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
    }

    testWidgets('invites a question before anything has been asked', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Ask about the portfolio.'), findsOneWidget);
    });

    testWidgets('answers in an interface, not only in text', (tester) async {
      // The whole point of the product, as one assertion: the agent's render
      // intent resolves through the SAME component registry a `?view=` read
      // uses, and a figure the backend formatted lands on screen verbatim.
      scriptTurn(const <AgentEvent>[
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
      await pump(tester);
      await ask(tester, 'what moved?');

      expect(find.text('what moved?'), findsOneWidget);
      expect(find.text('Bitcoin is the largest holding.'), findsOneWidget);
      expect(find.byType(ComponentHost), findsOneWidget);
      expect(find.text(r'$65,038.60'), findsOneWidget);
      // N-4: the raw member behind that display string never reaches a label.
      expect(find.textContaining('65038.6'), findsNothing);
    });

    testWidgets('shows the backend safe code and detail on failure', (
      tester,
    ) async {
      scriptTurn(const <AgentEvent>[
        AgentTurnEnded(AgentTurnState.failed),
        AgentFailed(
          code: 'dependency-unavailable',
          message: 'model provider unavailable',
        ),
      ]);
      await pump(tester);
      await ask(tester, 'what moved?');

      expect(find.text('model provider unavailable'), findsOneWidget);
      expect(find.text('dependency-unavailable'), findsOneWidget);
    });

    testWidgets('ignores an empty message rather than opening a turn', (
      tester,
    ) async {
      scriptTurn(const <AgentEvent>[]);
      await pump(tester);
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
