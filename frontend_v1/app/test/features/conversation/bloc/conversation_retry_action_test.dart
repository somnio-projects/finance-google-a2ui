import 'package:a2ui_v1/a2ui_v1.dart';
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

  group('$ConversationBloc retrying a surface action', () {
    test('Try again repeats the same action, timestamp and all', () async {
      const request = SurfaceActionRequest(
        action: 'drill_attribution',
        args: <String, String>{'driver': 'LINK'},
      );
      final agent = MockAgentRepository();
      when(
        () => agent.startTurn(
          text: any(named: 'text'),
          messages: any(named: 'messages'),
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      ).thenAnswer((_) => Stream<AgentEvent>.fromIterable(failed));
      final bloc = buildBloc(events: failed, agent: agent)
        ..add(
          const ConversationActionSent(
            surfaceId: 'turn-4b10-0',
            componentId: 'root',
            request: request,
          ),
        );
      await bloc.stream.firstWhere((s) => s.failure != null);

      bloc.add(const ConversationRetried());
      await bloc.stream.firstWhere(
        (s) => s.status == ConversationStatus.running,
      );
      await bloc.stream.firstWhere((s) => s.failure != null);

      // Twice, the same message both times: a retry is the same tap.
      final sent = sentMessages(agent);
      expect(sent, hasLength(2));
      expect(sent.first, sent.last);
      expect((sent.first as ActionMessage).context, request.args);
      // A tap echoes nothing, and neither does its retry.
      expect(bloc.state.entries, isEmpty);
      await bloc.close();
    });
  });
}
