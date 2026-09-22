part of 'conversation_bloc.dart';

/// How one agent event changes the transcript. A part of the bloc's library
/// so it reads the same private fields; split out under the 150-line budget
/// along the seam that was already there: *opening* a turn above, *applying*
/// what it streams here.
extension _ApplyEvents on ConversationBloc {
  Future<void> _apply(AgentEvent event, Emitter<ConversationState> emit) async {
    switch (event) {
      case AgentTurnStarted():
        // The running status is already set; nothing is shown for the open.
        emit(state.copyWith(status: () => ConversationStatus.running));
      case AgentSurfaceReady():
        await _fetchSurface(event, emit);
      case AgentAnswered():
        _append(emit, AgentSaid(event.text));
        emit(state.copyWith(suggestions: () => event.suggestions));
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

  Future<void> _fetchSurface(
    AgentSurfaceReady event,
    Emitter<ConversationState> emit,
  ) async {
    // The skeleton goes in first, so the reader sees the surface being
    // composed where it will land (OD-2); the fetch replaces it in place.
    final slot = state.entries.length;
    _append(emit, SurfacePending(event.view));
    final entry = await fetchSurfaceEntry(
      _viewsRepository,
      portfolioId: portfolioId,
      intent: event,
    );
    final entries = <ConversationEntry>[...state.entries];
    entries[slot] = entry;
    emit(state.copyWith(entries: () => entries));
  }

  void _append(Emitter<ConversationState> emit, ConversationEntry entry) =>
      emit(
        state.copyWith(
          entries: () => <ConversationEntry>[...state.entries, entry],
        ),
      );
}
