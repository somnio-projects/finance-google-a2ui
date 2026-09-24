import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/router/app_router.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fixtures.dart';
import 'app_router_harness.dart';

/// Asking twice through the route the chips use.
///
/// The Home chips and the Holdings hand-off both navigate to
/// `/ask?ask=<question>` (spec frontend/0009 OD-3). The Assistant is a branch
/// of a `StatefulShellRoute`, which keeps each branch's navigator alive — so
/// the page's element is reused and anything that only happens when the bloc
/// is *created* happens once, for the first question, and never again. The
/// reader taps a chip, lands on the Assistant, and nothing is asked.
///
/// This suite drives the real router, because the defect is in the
/// interaction between the route and the page and neither shows it alone.
void main() {
  group('buildRouter asking through /ask twice', () {
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
      when(
        () => agent.startTurn(
          text: any(named: 'text'),
          action: any(named: 'action'),
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      ).thenAnswer((_) => const Stream<AgentEvent>.empty());
    });

    Future<BuildContext> pumpAt(WidgetTester tester, String location) async {
      final router = buildRouter(initialLocation: location);
      await pumpRouter(
        tester,
        router,
        repository: views,
        registry: buildComponentRegistry(),
        agent: agent,
      );
      await tester.pumpAndSettle();
      return router.routerDelegate.navigatorKey.currentContext!;
    }

    testWidgets('asks the second question too', (tester) async {
      final context = await pumpAt(tester, askRoute('first question'));

      context.go(askRoute('second question'));
      await tester.pumpAndSettle();

      // Both turns, in order. Before the fix the second never started: the
      // branch was restored, the page's element reused, and the question
      // was delivered only where the bloc is constructed.
      verify(
        () => agent.startTurn(
          text: 'first question',
          action: any(named: 'action'),
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      ).called(1);
      verify(
        () => agent.startTurn(
          text: 'second question',
          action: any(named: 'action'),
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      ).called(1);
    });

    testWidgets('asks nothing when the tab is opened with no question', (
      tester,
    ) async {
      final context = await pumpAt(tester, askRoute('a question'));

      context.go(AppRoutes.conversation);
      await tester.pumpAndSettle();

      // The tab bar's own Assistant button carries no `ask`, and must not
      // replay whatever the last chip asked — so the count stays at the one
      // the chip started, not zero and not two.
      verify(
        () => agent.startTurn(
          text: 'a question',
          action: any(named: 'action'),
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      ).called(1);
    });

    testWidgets('does not repeat a question when the page rebuilds', (
      tester,
    ) async {
      await pumpAt(tester, askRoute('only once'));

      await tester.pump();
      await tester.pumpAndSettle();

      verify(
        () => agent.startTurn(
          text: 'only once',
          action: any(named: 'action'),
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      ).called(1);
    });
  });
}
