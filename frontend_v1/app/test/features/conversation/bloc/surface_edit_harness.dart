/// The seed and the stubs `conversation_surface_edit_test.dart` and
/// `conversation_surface_edit_races_test.dart` share (spec frontend/0026,
/// on the v1.0 wire: ADR-M D-6).
///
/// Extracted so both stay inside the 150-line budget — the remedy
/// `.claude/rules/frontend/testing.md` §3 prescribes.
library;

import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:finance_app/features/conversation/bloc/conversation_bloc.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

import '../../../helpers/a2ui_fixtures.dart';
import '../../../helpers/fixtures.dart';
import 'conversation_harness.dart';

/// Where the example surface's root edits are filed.
final String exampleEditKey = editKey(exampleSurfaceId, 'root');

/// A bloc that has already rendered [exampleSurface] after one question.
Future<ConversationBloc> editableBloc(MockAgentRepository agent) async {
  final bloc = buildBloc(
    events: <AgentEvent>[
      exampleSurface,
      const AgentTurnEnded(AgentTurnState.inputRequired),
    ],
    agent: agent,
  )..add(const ConversationMessageSent('what moved?'));
  await bloc.stream.firstWhere(
    (state) =>
        state.status == ConversationStatus.idle && state.entries.length == 2,
  );
  return bloc;
}

/// The example payload as a re-render would answer it, retitled so a test
/// can tell the two apart.
Map<String, Object?> rerenderedPayload() => <String, Object?>{
  ...holdingsAllocationExample,
  'title': 'after',
};

/// The edit to `top_n` every case sends.
const ConversationSurfaceEdited topNEdit = ConversationSurfaceEdited(
  surfaceId: exampleSurfaceId,
  componentId: 'root',
  option: 'top_n',
  value: '3',
);

/// A refusal of [callId] with the agent's own sentence.
AgentSurfaceMessages refusal(String callId) => AgentSurfaceMessages(<Decoded>[
  DecodedMessage(
    AgentFunctionResponse(
      functionCallId: callId,
      error: const FunctionError(
        code: 'INVALID_FUNCTION_CALL',
        message: "Option 'top_n' must be between 1 and 20.",
      ),
    ),
  ),
]);

/// The success answer to [callId], with the edited options echoed.
AgentSurfaceMessages success(String callId, Map<String, Object?> options) =>
    renderViewAnswer(
      surfaceId: exampleSurfaceId,
      callId: callId,
      payload: rerenderedPayload(),
      options: options,
    );
