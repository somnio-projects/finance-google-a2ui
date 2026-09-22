import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_card.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../components/attribution_waterfall/attribution_waterfall_card_test.dart'
    show bandCentre;
import '../../../helpers/catalog_snapshot.dart';
import '../../../helpers/fixtures.dart';
import 'conversation_harness.dart';

void main() {
  testWidgets('a tapped waterfall bar in the transcript opens the drill turn '
      '(frontend/0011 OD-4)', (tester) async {
    final agent = MockAgentRepository();
    final views = MockViewsRepository();
    final waterfall = CatalogSnapshot.load().exampleFor('AttributionWaterfall');
    when(
      () => views.fetchPortfolioViews(
        portfolioId: any(named: 'portfolioId'),
        views: any(named: 'views'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Ok<RenderedViews>(
        renderedViews(
          extraViews: <String, dynamic>{'attribution.waterfall.v1': waterfall},
        ),
      ),
    );
    scriptTurn(agent, const <AgentEvent>[
      AgentTurnStarted(),
      AgentSurfaceReady(
        index: 0,
        view: 'attribution.waterfall.v1',
        options: <String, String>{},
      ),
      AgentTurnEnded(AgentTurnState.inputRequired),
    ]);
    await pumpConversation(tester, agent: agent, views: views);
    await ask(tester, 'what moved?');
    expect(find.byType(AttributionWaterfallCard), findsOneWidget);

    await tester.tapAt(bandCentre(tester, 1));
    await tester.pumpAndSettle();

    final sent =
        verify(
              () => agent.startTurn(
                action: captureAny(named: 'action'),
                messageId: any(named: 'messageId'),
                contextId: any(named: 'contextId'),
              ),
            ).captured.single
            as SurfaceActionRequest;
    expect(sent.action, 'drill.attribution.v1');
    expect(sent.args.keys, <String>['driver']);
  });
}
