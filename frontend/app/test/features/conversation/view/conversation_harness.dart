/// The tree and the stubs `conversation_view_test.dart` drives.
///
/// Extracted so that suite stays inside the 150-line budget — the remedy
/// `.claude/rules/frontend/testing.md` §3 prescribes when a test file grows,
/// rather than dropping the comments that say why each assertion exists.
library;

import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/features/conversation/view/conversation_page.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';

/// A stand-in for the agent repository the conversation page streams from.
class MockAgentRepository extends Mock implements AgentRepository;

/// A stand-in for the views repository the surfaces are fetched through.
class MockViewsRepository extends Mock implements ViewsRepository;

/// Scripts [agent] to answer one turn with [events].
void scriptTurn(AgentRepository agent, List<AgentEvent> events) {
  when(
    () => agent.startTurn(
      text: any(named: 'text'),
      messageId: any(named: 'messageId'),
      contextId: any(named: 'contextId'),
    ),
  ).thenAnswer((_) => Stream<AgentEvent>.fromIterable(events));
}

/// Pumps the conversation page with both repositories and the real registry.
///
/// The surface is taller than the 800×600 default because the transcript is a
/// lazy `ListView`: with a full-height surface card in the middle, the answer
/// that follows it is never built and `find.text` cannot see a widget that
/// does not exist. That is a test-harness fact, not a product one — nothing
/// in the app depends on the window size.
Future<void> pumpConversation(
  WidgetTester tester, {
  required AgentRepository agent,
  required ViewsRepository views,
}) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return tester.pumpApp(
    const ConversationPage(),
    viewsRepository: views,
    agentRepository: agent,
    componentRegistry: buildComponentRegistry(),
  );
}

/// Types [text] into the composer and sends it.
Future<void> ask(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byIcon(Icons.send));
  await tester.pumpAndSettle();
}
