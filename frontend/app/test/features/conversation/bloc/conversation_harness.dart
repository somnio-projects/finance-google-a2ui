import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';

/// Stand-ins for the two repositories the bloc composes.
class MockAgentRepository extends Mock implements AgentRepository;

/// Stand-in for the read path a render intent resolves through.
class MockViewsRepository extends Mock implements ViewsRepository;

/// The view id the checked-in example payload carries.
const String exampleView = 'holdings.allocation.v1';

/// Builds a bloc whose agent emits [events] and whose read path answers
/// [viewsResult], defaulting to the example envelope.
ConversationBloc buildBloc({
  required List<AgentEvent> events,
  MockViewsRepository? views,
  Result<RenderedViews>? viewsResult,
}) {
  final agent = MockAgentRepository();
  final reads = views ?? MockViewsRepository();
  when(
    () => agent.startTurn(
      text: any(named: 'text'),
      action: any(named: 'action'),
      messageId: any(named: 'messageId'),
      contextId: any(named: 'contextId'),
    ),
  ).thenAnswer((_) => Stream<AgentEvent>.fromIterable(events));
  when(
    () => reads.fetchPortfolioViews(
      portfolioId: any(named: 'portfolioId'),
      views: any(named: 'views'),
      options: any(named: 'options'),
    ),
  ).thenAnswer((_) async => viewsResult ?? Ok<RenderedViews>(renderedViews()));
  return ConversationBloc(agentRepository: agent, viewsRepository: reads);
}

/// The surface event the backend emits for the example view.
const AgentSurfaceReady exampleSurface = AgentSurfaceReady(
  index: 0,
  view: exampleView,
  options: <String, String>{'top_n': '5'},
);
