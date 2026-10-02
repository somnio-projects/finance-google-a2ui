part of 'conversation_bloc.dart';

/// The sentence an edit is refused with when the agent never answered it —
/// the stream ended without an `agentFunctionResponse` for the call.
const String editUnanswered = 'The assistant did not answer this change.';

extension _EditSurfaces on ConversationBloc {
  /// `callAgentFunction("renderView")` for one changed option (ADR-M D-6).
  ///
  /// The whole option set is sent — the ones the component was rendered
  /// with, plus the edit — because the agent renders the view afresh and
  /// validates every option against the projection's own model. The answer
  /// is an `agentFunctionResponse` followed by an `updateDataModel` at the
  /// component's path, which [_absorb] applies like any other message.
  Future<void> _onSurfaceEdited(
    ConversationSurfaceEdited event,
    Emitter<ConversationState> emit,
  ) async {
    final surface = state.surfaces[event.surfaceId];
    final path = surface?.components[event.componentId]?.dataPath;
    final bound = path == null ? null : surface!.read(path);
    if (bound is! Map<String, Object?> || bound['view'] is! String) return;
    final key = editKey(event.surfaceId, event.componentId);
    final rendered = bound['options'];
    final options = <String, Object?>{
      ...?_intent[key] ?? (rendered is Map<String, Object?> ? rendered : null),
      event.option: event.value,
    };
    final callId = 'call-${_calls++}';
    _openCalls[callId] = key;
    _newestCall[key] = callId;
    _intent[key] = options;
    _setEdit(emit, key, SurfaceEditState(pendingOption: event.option));
    final call = renderViewCall(
      surfaceId: event.surfaceId,
      functionCallId: callId,
      catalogId: surface!.catalogId ?? catalogId,
      componentId: event.componentId,
      view: bound['view']! as String,
      options: options,
    );
    final answer = _agentRepository.startTurn(
      messages: <RendererMessage>[call],
      messageId: callId,
    );
    await for (final agentEvent in answer) {
      switch (agentEvent) {
        case AgentSurfaceMessages(:final messages):
          _absorb(messages, emit);
        case AgentFailed(:final message):
          _refuse(emit, callId, key, message);
        case AgentTurnStarted() || AgentAnswered() || AgentTurnEnded():
          break;
      }
    }
    _refuse(emit, callId, key, editUnanswered);
  }

  /// Refuses [callId] with [message] if it is still open and still the
  /// newest edit of [key]; a call already answered is left alone.
  void _refuse(
    Emitter<ConversationState> emit,
    String callId,
    String key,
    String message,
  ) {
    if (_openCalls.remove(callId) == null) return;
    if (_newestCall[key] != callId) return;
    _intent.remove(key);
    _setEdit(emit, key, SurfaceEditState(rejection: message));
  }

  void _setEdit(
    Emitter<ConversationState> emit,
    String key,
    SurfaceEditState edit,
  ) => emit(
    state.copyWith(
      edits: () => <String, SurfaceEditState>{...state.edits, key: edit},
    ),
  );
}
