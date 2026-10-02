import 'package:finance_app/components/order_ticket/order_ticket_card.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../components/order_ticket/order_ticket_harness.dart';
import '../../../helpers/pump_app.dart';
import 'conversation_harness.dart';

/// GGU-113 AC-4: the ticket rendered **from an agent-streamed surface**, not
/// from the catalog example pumped on its own — the gap the bug came through.
void main() {
  group('the order ticket the Assistant returns', () {
    late MockAgentRepository agent;
    late MockViewsRepository views;
    final viewId = orderTicketViewId();

    setUp(() {
      agent = MockAgentRepository();
      views = MockViewsRepository();
      when(
        () => views.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: <String>[viewId],
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Ok<RenderedViews>(
          renderedViews(
            extraViews: <String, dynamic>{viewId: orderTicketExample()},
          ),
        ),
      );
      scriptTurn(agent, <AgentEvent>[
        AgentSurfaceReady(
          index: 0,
          view: viewId,
          options: const <String, String>{'symbol': 'BTC'},
        ),
        const AgentAnswered(text: 'Here is the ticket.', views: <String>[]),
        const AgentTurnEnded(AgentTurnState.inputRequired),
      ]);
    });

    testWidgets('is editable, and an edit re-renders it (AC-1, AC-2)', (
      tester,
    ) async {
      await pumpConversation(tester, agent: agent, views: views);
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

      // The edit re-requested THIS view with the agent's options intact and
      // the edited one merged — through the read path, never as text.
      verify(
        () => views.fetchPortfolioViews(
          portfolioId: 'current',
          views: <String>[viewId],
          options: <String, String>{'symbol': 'BTC', 'side': other},
        ),
      ).called(1);
      expect(find.byType(OrderTicketCard), findsOneWidget);
      expect(find.text('Here is the ticket.'), findsOneWidget);
    });
  });
}
