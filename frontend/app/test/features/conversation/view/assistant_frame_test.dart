import 'dart:async';

import 'package:finance_app/features/conversation/view/assistant_bubbles.dart';
import 'package:finance_app/features/conversation/view/assistant_composer.dart';
import 'package:finance_app/features/conversation/view/assistant_skeleton.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';
import 'conversation_harness.dart';

void main() {
  group('the Assistant frame', () {
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

    testWidgets('wears the header the artboards draw', (tester) async {
      await pumpConversation(tester, agent: agent, views: views);
      expect(find.text('Assistant'), findsOneWidget);
      expect(find.text('Gemini · A2UI'), findsOneWidget);
      expect(find.text('Simulated'), findsOneWidget);
      expect(find.text(AssistantComposer.hint), findsOneWidget);
    });

    testWidgets('the question sits in a bubble on the right, the answer '
        'under the Assistant label, the chips above the composer', (
      tester,
    ) async {
      scriptTurn(agent, const <AgentEvent>[
        AgentTurnStarted(),
        AgentAnswered(
          text: 'Up today.',
          views: <String>[],
          suggestions: <Suggestion>[
            Suggestion(key: 'tax-lots', label: 'Tax lots'),
          ],
        ),
        AgentTurnEnded(AgentTurnState.completed),
      ]);
      await pumpConversation(tester, agent: agent, views: views);
      await ask(tester, 'what moved?');

      final bubble = tester.getRect(find.byType(UserBubble));
      final frame = tester.getRect(find.byType(Scaffold).first);
      expect(bubble.right, greaterThan(frame.center.dx));
      expect(find.text('Up today.'), findsOneWidget);
      // Two `Assistant`s: the header's and the turn's label.
      expect(find.text('Assistant'), findsNWidgets(2));
      expect(find.text('Tax lots'), findsOneWidget);
      expect(find.byType(StreamingDots), findsNothing);

      await tester.tap(find.text('Tax lots'));
      await tester.pumpAndSettle();
      // The chip echoed as the user's words and the row cleared and refilled.
      expect(find.byType(UserBubble), findsNWidgets(2));
      expect(find.text('Tax lots'), findsNWidgets(2));
    });

    testWidgets('a surface being composed shows the skeleton', (tester) async {
      scriptTurn(agent, const <AgentEvent>[
        AgentTurnStarted(),
        AgentSurfaceReady(
          index: 0,
          view: 'holdings.allocation.v1',
          options: <String, String>{},
        ),
        AgentTurnEnded(AgentTurnState.inputRequired),
      ]);
      // A fetch that never answers keeps the skeleton on screen. A completer,
      // not a delay: a pending timer fails the test at teardown.
      final never = Completer<Result<RenderedViews>>();
      when(
        () => views.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) => never.future);
      await pumpConversation(tester, agent: agent, views: views);
      await tester.enterText(find.byType(TextField), 'what moved?');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(SurfaceSkeleton), findsOneWidget);
      expect(find.text('Composing UI…'), findsOneWidget);
      expect(find.byType(StreamingDots), findsOneWidget);
      // The send button is quiet while the turn runs.
      await tester.enterText(find.byType(TextField), 'again');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      expect(find.byType(UserBubble), findsOneWidget);
      // The payload lands: the skeleton's slot becomes the surface, the turn
      // ends and the dots go quiet.
      never.complete(Ok<RenderedViews>(renderedViews()));
      await tester.pumpAndSettle();
      expect(find.byType(SurfaceSkeleton), findsNothing);
      expect(find.byType(StreamingDots), findsNothing);
      expect(find.text(r'$482,915.20'), findsOneWidget);
    });

    testWidgets('the mic is drawn and says it is not wired (OD-5)', (
      tester,
    ) async {
      await pumpConversation(tester, agent: agent, views: views);
      await tester.tap(find.byTooltip('Voice input'));
      await tester.pump();
      expect(find.text(AssistantComposer.micNotice), findsOneWidget);
    });
  });
}
