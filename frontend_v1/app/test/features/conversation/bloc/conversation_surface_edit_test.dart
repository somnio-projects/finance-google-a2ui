import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_app/a2ui/finance_catalog.dart';
import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'conversation_harness.dart';
import 'surface_edit_harness.dart';

/// Spec `frontend_v1/0001` AC-5: an edit is `callAgentFunction(renderView)`
/// and the widget updates from the `updateDataModel` that follows it.
void main() {
  late MockAgentRepository agent;
  late ConversationBloc bloc;

  setUp(() async {
    agent = MockAgentRepository();
    bloc = await editableBloc(agent);
  });

  tearDown(() => bloc.close());

  Future<ConversationState> edit(List<AgentEvent> answer) async {
    scriptAgent(agent, answer);
    bloc.add(topNEdit);
    final pending = await bloc.stream.first;
    expect(pending.edits[exampleEditKey]?.pendingOption, 'top_n');
    return await bloc.stream.firstWhere(
      (state) => state.edits[exampleEditKey]?.pendingOption == null,
    );
  }

  test('sends renderView with the merged options, then applies it', () async {
    final done = await edit(<AgentEvent>[
      const AgentTurnStarted(),
      success('call-0', const <String, Object?>{'top_n': '3'}),
      const AgentAnswered(text: 'ignored'),
      const AgentTurnEnded(AgentTurnState.completed),
    ]);
    final call = sentMessages(agent).single as CallAgentFunction;
    expect(call.call, 'renderView');
    expect(call.catalogId, financeCatalogId);
    expect(call.functionCallId, 'call-0');
    expect(call.args, <String, Object?>{
      'componentId': 'root',
      'view': exampleView,
      // The option the surface had (a number) plus the edit, verbatim.
      'options': <String, Object?>{'top_n': '3'},
    });
    final surface = done.surfaces[exampleSurfaceId]!;
    expect(surface.read('/root/payload/title'), 'after');
    expect(done.edits, isEmpty);
    // An edit re-renders the entry it came from; it appends nothing.
    expect(done.entries, hasLength(2));
  });

  test('a refused call shows the agent sentence and keeps the data', () async {
    final done = await edit(<AgentEvent>[refusal('call-0')]);
    expect(
      done.edits[exampleEditKey],
      const SurfaceEditState(
        rejection: "Option 'top_n' must be between 1 and 20.",
      ),
    );
    expect(done.surfaces[exampleSurfaceId]!.read('/root/options/top_n'), 5);
  });

  test('a failed request is refused with its own message', () async {
    final done = await edit(const <AgentEvent>[
      AgentFailed(code: 'transport-unavailable', message: 'unreachable'),
    ]);
    expect(done.edits[exampleEditKey]?.rejection, 'unreachable');
  });

  test('a request that ends unanswered says so', () async {
    final done = await edit(const <AgentEvent>[
      AgentTurnEnded(AgentTurnState.completed),
    ]);
    expect(done.edits[exampleEditKey]?.rejection, editUnanswered);
  });

  test('an edit of nothing bound sends nothing', () async {
    bloc
      ..add(
        const ConversationSurfaceEdited(
          surfaceId: 'unknown',
          componentId: 'root',
          option: 'x',
          value: 'y',
        ),
      )
      ..add(
        const ConversationSurfaceEdited(
          surfaceId: exampleSurfaceId,
          componentId: 'not-a-component',
          option: 'x',
          value: 'y',
        ),
      );
    await pumpEventQueue();
    // Only the question that rendered the surface was ever sent.
    expect(sentMessages(agent), isEmpty);
  });
}
