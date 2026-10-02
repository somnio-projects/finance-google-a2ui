import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_app/components/order_ticket/order_ticket_card.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../components/order_ticket/order_ticket_harness.dart';
import '../../../helpers/a2ui_fixtures.dart';
import 'conversation_harness.dart';

/// GGU-113 AC-4 on the v1.0 wire: the ticket rendered **from an
/// agent-streamed surface**, and an edit sent as `callAgentFunction` with
/// the surface's options merged (spec `frontend_v1/0001` AC-5).
void main() {
  group('the order ticket the Assistant returns', () {
    late MockAgentRepository agent;

    setUp(() {
      agent = MockAgentRepository();
      scriptTurn(agent, <AgentEvent>[
        surfaceEvent(
          surfaceId: 'turn-1-0',
          component: 'OrderTicket',
          payload: orderTicketExample(),
          options: const <String, Object?>{'symbol': 'BTC'},
        ),
        const AgentAnswered(text: 'Here is the ticket.'),
        const AgentTurnEnded(AgentTurnState.inputRequired),
      ]);
    });

    testWidgets('is editable, and an edit is a renderView call (AC-5)', (
      tester,
    ) async {
      await pumpConversation(tester, agent: agent);
      await ask(tester, 'buy 0.1 BTC');

      final card = tester.widget<OrderTicketCard>(find.byType(OrderTicketCard));
      expect(card.onOptionChanged, isNotNull);
      for (final field in tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      )) {
        expect(field.enabled, isTrue);
      }

      final inputs = orderTicketExample()['inputs']! as List<dynamic>;
      final side = inputs.cast<Map<String, dynamic>>().firstWhere(
        (input) => input['option'] == 'side',
      );
      final choices = (side['choices']! as List<dynamic>).cast<String>();
      final other = choices.firstWhere((c) => c != side['value']);
      // `inputs[]` arrives in the contract's order (N-10): `symbol` is the
      // first choice control and `side` the second.
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text(other).last);
      await tester.pumpAndSettle();

      final sent = verify(
        () => agent.startTurn(
          text: any(named: 'text'),
          messages: captureAny(named: 'messages'),
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      ).captured.cast<List<RendererMessage>>().expand((m) => m).toList();
      final call = sent.single as CallAgentFunction;
      expect(call.surfaceId, 'turn-1-0');
      expect(call.args, <String, Object?>{
        'componentId': 'root',
        'view': orderTicketViewId(),
        'options': <String, Object?>{'symbol': 'BTC', 'side': other},
      });
      expect(find.byType(OrderTicketCard), findsOneWidget);
      expect(find.text('Here is the ticket.'), findsOneWidget);
    });
  });
}
