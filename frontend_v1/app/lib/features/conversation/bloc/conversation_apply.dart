part of 'conversation_bloc.dart';

extension _ApplyEvents on ConversationBloc {
  void _apply(AgentEvent event, Emitter<ConversationState> emit) {
    switch (event) {
      case AgentTurnStarted():
        // The running status is already set; nothing is shown for the open.
        emit(state.copyWith(status: () => ConversationStatus.running));
      case AgentSurfaceMessages(:final messages):
        _absorb(messages, emit);
      case AgentAnswered():
        emit(
          state.copyWith(
            entries: () => <ConversationEntry>[
              ...state.entries,
              AgentSaid(event.text),
            ],
            suggestions: () => event.suggestions,
          ),
        );
      case AgentTurnEnded():
        // N-11: `completed` and `input_required` are both successes. Only
        // `failed` is a failure, and its reason arrives in the next event.
        emit(
          state.copyWith(
            status: () => event.state == AgentTurnState.failed
                ? ConversationStatus.failed
                : ConversationStatus.idle,
          ),
        );
      case AgentFailed():
        emit(
          state.copyWith(
            status: () => ConversationStatus.failed,
            failure: () => event,
          ),
        );
    }
  }

  /// Applies one batch of A2UI messages and repaints **once** — the
  /// extension spec's "SHOULD NOT repaint until all messages in the list
  /// have been processed".
  ///
  /// A surface the batch created joins the transcript where it landed; one
  /// it deleted leaves it. A function response settles the edit it answers.
  void _absorb(List<Decoded> messages, Emitter<ConversationState> emit) {
    final before = state.surfaces;
    final outcome = _processor.process(before, messages);
    final after = outcome.surfaces;
    final edits = <String, SurfaceEditState>{...state.edits};
    for (final response in outcome.responses) {
      _settle(response, edits);
    }
    emit(
      state.copyWith(
        surfaces: () => after,
        edits: () => edits,
        rendererErrors: () => <RendererError>[
          ...state.rendererErrors,
          ...outcome.errors,
        ],
        entries: () => <ConversationEntry>[
          for (final entry in state.entries)
            if (entry is! AgentSurface || after[entry.surfaceId] != null) entry,
          for (final id in after.surfaces.keys)
            if (before[id] == null) AgentSurface(id),
        ],
      ),
    );
  }

  /// Settles the edit [response] answers: a refusal leaves the agent's
  /// sentence under the component (the designed error state, AC-5); a
  /// success clears the edit, because the `updateDataModel` that follows it
  /// already re-rendered the component.
  void _settle(
    AgentFunctionResponse response,
    Map<String, SurfaceEditState> edits,
  ) {
    final key = _openCalls.remove(response.functionCallId);
    if (key == null || _newestCall[key] != response.functionCallId) return;
    _intent.remove(key);
    final error = response.error;
    if (error == null) {
      edits.remove(key);
    } else {
      edits[key] = SurfaceEditState(rejection: error.message);
    }
  }
}
