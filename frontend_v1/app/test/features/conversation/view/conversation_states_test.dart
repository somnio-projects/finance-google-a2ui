import 'dart:async';

import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/features/conversation/view/assistant_bubbles.dart';
import 'package:finance_app/features/conversation/view/conversation_page.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';

class _MockAgentRepository extends Mock implements AgentRepository;

class _MockViewsRepository extends Mock implements ViewsRepository;

void main() {
  group('$ConversationPage while a turn runs', () {
    late _MockAgentRepository agent;
    late _MockViewsRepository views;
    late StreamController<AgentEvent> turn;

    setUp(() {
      agent = _MockAgentRepository();
      views = _MockViewsRepository();
      turn = StreamController<AgentEvent>();
      when(
        () => agent.startTurn(
          text: any(named: 'text'),
          messages: any(named: 'messages'),
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      ).thenAnswer((_) => turn.stream);
    });

    Future<void> pump(WidgetTester tester) => tester.pumpApp(
      const ConversationPage(),
      viewsRepository: views,
      agentRepository: agent,
      componentRegistry: buildComponentRegistry(),
    );

    testWidgets('shows progress until the turn reaches a terminal state', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'what moved?');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(StreamingDots), findsOneWidget);

      turn.add(const AgentTurnEnded(AgentTurnState.completed));
      await turn.close();
      await tester.pumpAndSettle();

      expect(find.byType(StreamingDots), findsNothing);
    });

    testWidgets('stops showing progress when a turn ends mid-flight', (
      tester,
    ) async {
      // A stream that closes without a terminal status. Leaving the surface
      // spinning forever would be worse than showing what arrived.
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'what moved?');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();

      await turn.close();
      await tester.pumpAndSettle();

      expect(find.byType(StreamingDots), findsNothing);
      expect(find.text('what moved?'), findsOneWidget);
    });

    testWidgets('sends on the keyboard action as well as the button', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'what moved?');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      verify(
        () => agent.startTurn(
          text: 'what moved?',
          messages: any(named: 'messages'),
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      ).called(1);
      await turn.close();
      await tester.pumpAndSettle();
    });

    testWidgets('shows the part of a surface the catalog refuses (AC-3)', (
      tester,
    ) async {
      // A payoff chart directly under the surface breaks ADR-M D-4: it may
      // only sit under a ticket. Nothing is drawn for it, and the code the
      // renderer would report is on screen instead of a blank space.
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'what moved?');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();

      turn.add(
        surfaceEvent(
          surfaceId: 's-0',
          component: 'RiskPayoffChart',
          payload: const <String, Object?>{'view': 'payoff.curve.v1'},
        ),
      );
      await turn.close();
      await tester.pumpAndSettle();

      expect(find.textContaining('UNALLOWED_PARENT'), findsOneWidget);
    });
  });
}
