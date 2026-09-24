import 'package:finance_app/features/conversation/view/assistant_chips.dart';
import 'package:finance_app/features/conversation/view/turn_failure_card.dart';
import 'package:finance_app/features/conversation/view/turn_failure_notice.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import 'conversation_harness.dart';

/// GGU-111, as the reporter saw it: `model provider unavailable` over
/// `dependency-unavailable`, in red, with no chips and no way forward.
void main() {
  const chips = <Suggestion>[Suggestion(key: 'drivers', label: 'Drivers')];
  const outage = AgentFailed(
    code: 'dependency-unavailable',
    message: 'model provider unavailable',
  );

  group(TurnFailureCard, () {
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

    /// One good turn, so the chips exist, then a failed one.
    Future<void> failAfterAnAnswer(WidgetTester tester) async {
      scriptTurn(agent, const <AgentEvent>[
        AgentAnswered(text: 'NVDA led.', views: <String>[], suggestions: chips),
        AgentTurnEnded(AgentTurnState.completed),
      ]);
      await pumpConversation(tester, agent: agent, views: views);
      await ask(tester, 'what moved?');
      scriptTurn(agent, const <AgentEvent>[
        AgentTurnEnded(AgentTurnState.failed),
        outage,
      ]);
      await ask(tester, 'and the drivers?');
    }

    testWidgets('shows a sentence and a Try again, never the code (AC-1)', (
      tester,
    ) async {
      await failAfterAnAnswer(tester);

      expect(find.byType(TurnFailureCard), findsOneWidget);
      expect(find.text(turnFailureNotice(outage)), findsOneWidget);
      expect(find.text('model provider unavailable'), findsNothing);
      expect(find.text('dependency-unavailable'), findsNothing);
      expect(find.text(turnRetryLabel), findsOneWidget);
    });

    testWidgets('the composer and the chips stay usable (AC-2)', (
      tester,
    ) async {
      await failAfterAnAnswer(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isTrue);
      expect(
        find.descendant(
          of: find.byType(SuggestionChips),
          matching: find.text('Drivers'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Try again re-sends the question and clears the card', (
      tester,
    ) async {
      await failAfterAnAnswer(tester);
      scriptTurn(agent, const <AgentEvent>[
        AgentAnswered(text: 'Chips and GLD.', views: <String>[]),
        AgentTurnEnded(AgentTurnState.completed),
      ]);

      await tester.tap(find.text(turnRetryLabel));
      await tester.pumpAndSettle();

      expect(find.byType(TurnFailureCard), findsNothing);
      expect(find.text('Chips and GLD.'), findsOneWidget);
      // The question was not echoed a second time.
      expect(find.text('and the drivers?'), findsOneWidget);
      verify(
        () => agent.startTurn(
          text: 'and the drivers?',
          action: any(named: 'action'),
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      ).called(2);
    });
  });
}
