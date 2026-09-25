import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/features/conversation/view/conversation_page.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import 'conversation_harness.dart';

void main() {
  group('$ConversationPage with a question in hand', () {
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
      scriptTurn(agent, const <AgentEvent>[]);
    });

    testWidgets('sends the question the route carried, verbatim', (
      tester,
    ) async {
      // The Home chips and the Holdings hand-off arrive through
      // `/ask?ask=…` (spec frontend/0009 OD-3); the page must ask it without
      // the user touching the composer.
      const question = 'Tell me about my BTC position';
      await tester.pumpApp(
        const ConversationPage(initialQuestion: question),
        viewsRepository: views,
        agentRepository: agent,
        componentRegistry: buildComponentRegistry(),
      );
      await tester.pumpAndSettle();
      expect(find.text(question), findsOneWidget);
      verify(
        () => agent.startTurn(
          text: question,
          action: any(named: 'action'),
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      ).called(1);
    });

    testWidgets('an empty question sends nothing', (tester) async {
      await tester.pumpApp(
        const ConversationPage(initialQuestion: ''),
        viewsRepository: views,
        agentRepository: agent,
        componentRegistry: buildComponentRegistry(),
      );
      await tester.pumpAndSettle();
      verifyNever(
        () => agent.startTurn(
          text: any(named: 'text'),
          action: any(named: 'action'),
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      );
    });
  });
}
