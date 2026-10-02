import 'dart:async';

import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_app/features/conversation/view/assistant_bubbles.dart';
import 'package:finance_app/features/conversation/view/assistant_composer.dart';
import 'package:finance_app/features/conversation/view/voice_notice.dart';
import 'package:finance_app/skeleton/surface_skeleton.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/a2ui_fixtures.dart';
import '../../../helpers/fixtures.dart';
import 'conversation_harness.dart';

void main() {
  group('the Assistant frame', () {
    late MockAgentRepository agent;

    setUp(() {
      agent = MockAgentRepository();
    });

    testWidgets('wears the header the artboards draw', (tester) async {
      await pumpConversation(tester, agent: agent);
      expect(find.text('Assistant'), findsOneWidget);
      expect(find.text('Gemini · A2UI'), findsOneWidget);
      // "portfolio", not bare "Simulated": next to the model pill, the
      // short form said the assistant was simulated, which is false — the
      // turn is a real Gemini call. It is the data that is seeded.
      expect(find.text('Simulated portfolio'), findsOneWidget);
      expect(find.text('Simulated'), findsNothing);
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
          suggestions: <Suggestion>[
            Suggestion(key: 'tax-lots', label: 'Tax lots'),
          ],
        ),
        AgentTurnEnded(AgentTurnState.completed),
      ]);
      await pumpConversation(tester, agent: agent);
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

    testWidgets('a surface buffered until its root shows the skeleton', (
      tester,
    ) async {
      // The adjacency-list rule: nothing is visible before `root` arrives.
      // A controller, not a delay: a pending timer fails at teardown.
      final turn = StreamController<AgentEvent>();
      when(
        () => agent.startTurn(
          text: any(named: 'text'),
          messages: any(named: 'messages'),
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      ).thenAnswer((_) => turn.stream);
      await pumpConversation(tester, agent: agent);
      await tester.enterText(find.byType(TextField), 'what moved?');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      turn.add(
        const AgentSurfaceMessages(<Decoded>[
          DecodedMessage(CreateSurface(surfaceId: 's-0')),
        ]),
      );
      await tester.pump();
      expect(find.byType(SurfaceSkeleton), findsOneWidget);
      expect(find.byType(StreamingDots), findsOneWidget);
      // The send button is quiet while the turn runs.
      await tester.enterText(find.byType(TextField), 'again');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      expect(find.byType(UserBubble), findsOneWidget);
      // The root lands with its data: the skeleton becomes the surface, the
      // turn ends and the dots go quiet.
      final rooted =
          surfaceEvent(
                surfaceId: 's-0',
                component: 'HoldingsSummary',
                payload: holdingsAllocationExample,
              ).messages.single
              as DecodedMessage;
      final create = rooted.message as CreateSurface;
      turn
        ..add(
          AgentSurfaceMessages(<Decoded>[
            DecodedMessage(
              UpdateDataModel(surfaceId: 's-0', value: create.dataModel),
            ),
            DecodedMessage(
              UpdateComponents(surfaceId: 's-0', components: create.components),
            ),
          ]),
        )
        ..add(const AgentTurnEnded(AgentTurnState.inputRequired));
      await turn.close();
      await tester.pumpAndSettle();
      expect(find.byType(SurfaceSkeleton), findsNothing);
      expect(find.byType(StreamingDots), findsNothing);
      expect(find.text(r'$482,915.20'), findsOneWidget);
    });

    testWidgets('the mic is drawn and never inert (0011 OD-5, 0022 AC-1)', (
      tester,
    ) async {
      // 0011 OD-5 drew it and said it was not wired. It is wired now, and
      // what stayed is the half that mattered: on a build with no engine —
      // which is every build a test runs — the tooltip says so and the tap
      // still produces a sentence. `voice_composer_test.dart` owns the rest.
      await pumpConversation(tester, agent: agent);
      expect(find.byTooltip(voiceUnavailableTooltip), findsOneWidget);
      await tester.tap(find.byTooltip(voiceUnavailableTooltip));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
