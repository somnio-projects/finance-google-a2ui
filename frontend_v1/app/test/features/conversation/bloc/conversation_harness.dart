import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_app/a2ui/finance_catalog.dart';
import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/a2ui_fixtures.dart';
import '../../../helpers/fixtures.dart';

/// Stand-in for the one repository the bloc composes.
class MockAgentRepository extends Mock implements AgentRepository;

/// The surface id the example surface is created under.
const String exampleSurfaceId = 's-0';

/// The view id the checked-in example payload carries.
const String exampleView = 'holdings.allocation.v1';

/// Scripts [agent] so every request answers with [events].
void scriptAgent(MockAgentRepository agent, List<AgentEvent> events) => when(
  () => agent.startTurn(
    text: any(named: 'text'),
    messages: any(named: 'messages'),
    messageId: any(named: 'messageId'),
    contextId: any(named: 'contextId'),
  ),
).thenAnswer((_) => Stream<AgentEvent>.fromIterable(events));

/// Builds a bloc whose agent answers every request with [events].
ConversationBloc buildBloc({
  required List<AgentEvent> events,
  MockAgentRepository? agent,
}) {
  final repository = agent ?? MockAgentRepository();
  scriptAgent(repository, events);
  return ConversationBloc(
    agentRepository: repository,
    catalogId: financeCatalogId,
    clock: const FixedActionClock(),
  );
}

/// The `createSurface` the backend emits for the example allocation, with
/// `top_n: 5` in its options (ADR-M D-3).
final AgentSurfaceMessages exampleSurface = surfaceEvent(
  surfaceId: exampleSurfaceId,
  component: 'HoldingsSummary',
  payload: holdingsAllocationExample,
  options: const <String, Object?>{'top_n': 5},
);

/// Every A2UI message the bloc sent, across all of its requests, in order.
List<RendererMessage> sentMessages(MockAgentRepository agent) =>
    verify(
          () => agent.startTurn(
            text: any(named: 'text'),
            messages: captureAny(named: 'messages'),
            messageId: any(named: 'messageId'),
            contextId: any(named: 'contextId'),
          ),
        ).captured
        .cast<List<RendererMessage>>()
        .expand((messages) => messages)
        .toList();
