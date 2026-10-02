part of 'conversation_bloc.dart';

/// How an edit of one surface's option re-renders that surface (GGU-113).
///
/// A part of the bloc's library, like `conversation_apply.dart`, so it reads
/// the same private fields; split out under the 150-line budget along the
/// seam ADR-K D-11 already draws: a *turn* opens and applies events above, an
/// *edit* re-requests one view here. The edit never reaches the agent — the
/// declared option is the whole message, and the read endpoint that answers
/// it validates the value against the registry that declared it (D-3), so a
/// refused edit comes back as the backend's own sentence and the previous
/// payload stays on screen under it.
extension _EditSurfaces on ConversationBloc {
  Future<void> _onSurfaceEdited(
    ConversationSurfaceEdited event,
    Emitter<ConversationState> emit,
  ) async {
    final current = _surfaceAt(event.slot);
    if (current == null) return;
    final options = <String, String>{
      ...current.options,
      event.option: event.value,
    };
    _editsInFlight[event.slot] = options;
    _replace(emit, event.slot, current.editing(event.option, options));
    final result = await _viewsRepository.fetchPortfolioViews(
      portfolioId: portfolioId,
      views: <String>[current.payload.view],
      options: options,
    );
    // A newer edit of the same surface owns the slot now; this answer is
    // stale and must not overwrite it (the rule `OrderTicketBloc` keeps).
    if (!identical(_editsInFlight[event.slot], options)) return;
    _editsInFlight.remove(event.slot);
    final latest = _surfaceAt(event.slot);
    if (latest == null) return;
    _replace(emit, event.slot, switch (result) {
      Ok<RenderedViews>(:final value) =>
        switch (value.views[current.payload.view]) {
          null => latest.refused(surfaceWithoutPayload, current.options),
          final payload => latest.rendered(payload, options),
        },
      Err<RenderedViews>(:final failure) => latest.refused(
        failure.message,
        current.options,
      ),
    });
  }

  /// The surface at [slot], or null when the slot is not a surface — an
  /// index from a widget that outlived its transcript is ignored, not thrown.
  AgentSurface? _surfaceAt(int slot) {
    final entries = state.entries;
    if (slot < 0 || slot >= entries.length) return null;
    final entry = entries[slot];
    return entry is AgentSurface ? entry : null;
  }

  void _replace(
    Emitter<ConversationState> emit,
    int slot,
    ConversationEntry entry,
  ) {
    final entries = <ConversationEntry>[...state.entries];
    entries[slot] = entry;
    emit(state.copyWith(entries: () => entries));
  }
}
