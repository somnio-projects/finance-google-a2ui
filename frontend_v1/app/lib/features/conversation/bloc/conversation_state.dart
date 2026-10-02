part of 'conversation_bloc.dart';

/// Where the conversation is.
///
/// Loading and failure are **transport** state and live here, never in a
/// payload: no projection carries an `isLoading` flag (ADR-K D-19).
enum ConversationStatus {
  /// No turn is running. The initial state, and the state a finished turn
  /// returns to — including one that ended `input_required`, which is a
  /// success (N-11).
  idle,

  /// A turn is in flight. Surfaces may still arrive.
  running,

  /// The turn failed; see [ConversationState.failure].
  failed,
}

/// What the conversation screen renders.
final class ConversationState extends Equatable {
  /// Creates a state.
  const ConversationState({
    this.status = ConversationStatus.idle,
    this.entries = const <ConversationEntry>[],
    this.suggestions = const <Suggestion>[],
    this.failure,
    this.lastTurn,
    this.surfaces = const SurfaceSet(),
    this.edits = const <String, SurfaceEditState>{},
    this.rendererErrors = const <RendererError>[],
  });

  /// Whether a turn is running.
  final ConversationStatus status;

  /// Everything said and shown so far, oldest first.
  final List<ConversationEntry> entries;

  /// The follow-ups the last **answer** recommended, in the backend's order.
  ///
  /// Kept across a turn that fails: the chips are the backend's last standing
  /// recommendation, and a person whose question just failed needs them more,
  /// not less (GGU-111 AC-2). The view hides them while a turn runs; a new
  /// answer replaces them.
  final List<Suggestion> suggestions;

  /// Why the last turn failed, when it did — the backend's own safe `code`
  /// and `message`, never a library string and never a stack trace.
  final AgentFailed? failure;

  /// What the most recent turn sent, so *Try again* can send it once more.
  final TurnRequest? lastTurn;

  /// Every live A2UI surface, as the processor left it.
  final SurfaceSet surfaces;

  /// Each component's last edit, by `editKey(surfaceId, componentId)`.
  final Map<String, SurfaceEditState> edits;

  /// What the processor could not apply, in order — the per-message errors
  /// the extension spec says to report and move past.
  final List<RendererError> rendererErrors;

  /// Copies this state, replacing only the fields whose getter is supplied.
  ///
  /// Each parameter is a getter rather than a value so that passing `null`
  /// *retains* the old value while `() => null` *clears* it.
  ConversationState copyWith({
    ConversationStatus Function()? status,
    List<ConversationEntry> Function()? entries,
    List<Suggestion> Function()? suggestions,
    AgentFailed? Function()? failure,
    TurnRequest? Function()? lastTurn,
    SurfaceSet Function()? surfaces,
    Map<String, SurfaceEditState> Function()? edits,
    List<RendererError> Function()? rendererErrors,
  }) => ConversationState(
    status: status != null ? status() : this.status,
    entries: entries != null ? entries() : this.entries,
    suggestions: suggestions != null ? suggestions() : this.suggestions,
    failure: failure != null ? failure() : this.failure,
    lastTurn: lastTurn != null ? lastTurn() : this.lastTurn,
    surfaces: surfaces != null ? surfaces() : this.surfaces,
    edits: edits != null ? edits() : this.edits,
    rendererErrors: rendererErrors != null
        ? rendererErrors()
        : this.rendererErrors,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    entries,
    suggestions,
    failure,
    lastTurn,
    surfaces,
    edits,
    rendererErrors,
  ];
}
