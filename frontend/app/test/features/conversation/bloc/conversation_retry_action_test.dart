import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'conversation_harness.dart';

/// GGU-111 AC-1, the chip half: split from `conversation_retry_test.dart`
/// under the 150-line budget. A chip travels as its **key** (0011 OD-3), and
/// so must its retry — the label is what the person read, never what is sent.
void main() {
  const failed = <AgentEvent>[
    AgentTurnEnded(AgentTurnState.failed),
    AgentFailed(
      code: 'dependency-unavailable',
      message: 'model provider unavailable',
    ),
  ];

  group('$ConversationBloc retrying a chip', () {
    test("Try again repeats a chip's action, never its label", () async {
      const request = SurfaceActionRequest(
        action: 'ask.suggested.v1',
        args: <String, String>{'suggestion': 'drivers'},
      );
      final agent = MockAgentRepository();
      when(
        () => agent.startTurn(
          text: any(named: 'text'),
          action: any(named: 'action'),
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      ).thenAnswer((_) => Stream<AgentEvent>.fromIterable(failed));
      final bloc =
          ConversationBloc(
            agentRepository: agent,
            viewsRepository: MockViewsRepository(),
          )..add(
            const ConversationSuggestionTapped(
              Suggestion(key: 'drivers', label: 'Drivers'),
            ),
          );
      await bloc.stream.firstWhere((s) => s.failure != null);

      bloc.add(const ConversationRetried());
      await bloc.stream.firstWhere(
        (s) => s.status == ConversationStatus.running,
      );
      await bloc.stream.firstWhere((s) => s.failure != null);

      // Twice with the action, never once with the label as a sentence.
      verify(
        () => agent.startTurn(
          text: any(named: 'text'),
          action: request,
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      ).called(2);
      verifyNever(
        () => agent.startTurn(
          text: 'Drivers',
          action: any(named: 'action'),
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      );
      // The chip's label was echoed once, by the tap — not again by the retry.
      expect(bloc.state.entries, const <ConversationEntry>[
        UserSaid('Drivers'),
      ]);
      await bloc.close();
    });
  });
}
