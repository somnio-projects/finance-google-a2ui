import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_card.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../components/attribution_waterfall/attribution_waterfall_card_test.dart'
    show bandCentre;
import '../../../helpers/a2ui_fixtures.dart';
import '../../../helpers/catalog_snapshot.dart';
import 'conversation_harness.dart';

void main() {
  testWidgets('a tapped waterfall bar sends action(drill_attribution) '
      '(spec frontend_v1/0001 AC-6)', (tester) async {
    final agent = MockAgentRepository();
    final waterfall = CatalogSnapshot.load().exampleForView(
      'attribution.waterfall.v1',
    );
    scriptTurn(agent, <AgentEvent>[
      const AgentTurnStarted(),
      surfaceEvent(
        surfaceId: 'turn-4b10-0',
        component: 'AttributionWaterfall',
        payload: waterfall,
      ),
      const AgentTurnEnded(AgentTurnState.inputRequired),
    ]);
    await pumpConversation(tester, agent: agent);
    await ask(tester, 'what moved?');
    expect(find.byType(AttributionWaterfallCard), findsOneWidget);

    await tester.tapAt(bandCentre(tester, 1));
    await tester.pumpAndSettle();

    final sent = verify(
      () => agent.startTurn(
        text: any(named: 'text'),
        messages: captureAny(named: 'messages'),
        messageId: any(named: 'messageId'),
        contextId: any(named: 'contextId'),
      ),
    ).captured.cast<List<RendererMessage>>().expand((m) => m).toList();
    final action = sent.single as ActionMessage;
    expect(action.name, 'drill_attribution');
    expect(action.surfaceId, 'turn-4b10-0');
    expect(action.sourceComponentId, 'root');
    expect(action.timestamp, FixedActionClock.instant);
    expect(action.context.keys, <String>['driver']);
  });
}
