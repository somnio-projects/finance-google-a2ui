import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:finance_app/features/conversation/bloc/conversation_entry.dart';
import 'package:finance_app/features/conversation/bloc/surface_fetch.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

export 'package:finance_app/features/conversation/bloc/conversation_entry.dart';

part 'conversation_apply.dart';
part 'conversation_edit.dart';
part 'conversation_event.dart';
part 'conversation_state.dart';

/// Runs an agent turn and turns it into things to show, as they arrive.
///
/// The bloc talks to two repositories and to nothing else. It performs no
/// arithmetic and no formatting: the answer text is the backend's, and a
/// surface is a payload the backend shaped (N-1, N-2).
///
/// **Surfaces are emitted while the turn is still running** (ADR-K D-19).
/// Each `render-intent` is fetched and appended the moment it lands, so the
/// first widget appears before the answer text — the visible difference
/// between this and a REST dashboard.
class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  /// Creates a bloc over the agent and the view repositories.
  ConversationBloc({
    required AgentRepository agentRepository,
    required ViewsRepository viewsRepository,
    this.portfolioId = 'current',
  }) : _agentRepository = agentRepository,
       _viewsRepository = viewsRepository,
       super(const ConversationState()) {
    on<ConversationMessageSent>(_onMessageSent);
    on<ConversationSuggestionTapped>(_onSuggestionTapped);
    on<ConversationActionSent>(_onActionSent);
    on<ConversationRetried>(_onRetried);
    on<ConversationSurfaceEdited>(_onSurfaceEdited);
  }

  /// The portfolio a surface is rendered for. `current` resolves to the
  /// authenticated caller's own portfolio.
  final String portfolioId;

  final AgentRepository _agentRepository;
  final ViewsRepository _viewsRepository;

  /// The options of the edit in flight, per slot, compared by identity when
  /// an answer lands so a slow re-render cannot overwrite a newer edit.
  final Map<int, Map<String, String>> _editsInFlight =
      <int, Map<String, String>>{};

  Future<void> _onMessageSent(
    ConversationMessageSent event,
    Emitter<ConversationState> emit,
  ) => _run(emit, echo: event.text, text: event.text);

  Future<void> _onSuggestionTapped(
    ConversationSuggestionTapped event,
    Emitter<ConversationState> emit,
  ) => _run(
    emit,
    echo: event.suggestion.label,
    action: SurfaceActionRequest(
      action: 'ask.suggested.v1',
      args: <String, String>{'suggestion': event.suggestion.key},
    ),
  );

  Future<void> _onActionSent(
    ConversationActionSent event,
    Emitter<ConversationState> emit,
  ) => _run(emit, action: event.request);

  /// The same request once more, with no echo: the bubble that asked is
  /// already on screen (GGU-111 AC-1). Nothing to repeat is a no-op.
  ///
  /// The retry therefore carries the same `messageId` as the attempt that
  /// failed — it is derived from the transcript's length, which an echo-less
  /// turn does not change. The backend reads the id and de-duplicates nothing
  /// (ADR-J), so this is harmless today; if it ever starts to, the id needs a
  /// retry counter, not a second bubble.
  Future<void> _onRetried(
    ConversationRetried event,
    Emitter<ConversationState> emit,
  ) async {
    final last = state.lastTurn;
    if (last == null) return;
    await _run(emit, text: last.text, action: last.action);
  }

  /// One turn, whatever opened it: a typed sentence, a chip, or a surface's
  /// tap. [echo] is what the transcript shows as the user's turn — the words
  /// typed, or the chip's label; a bar tap shows nothing and lets the answer
  /// speak (spec frontend/0011 OD-3, OD-4).
  Future<void> _run(
    Emitter<ConversationState> emit, {
    String? echo,
    String? text,
    SurfaceActionRequest? action,
  }) async {
    // The chips are NOT cleared here. They are the last answer's standing
    // recommendation and they survive a failed turn (GGU-111 AC-2); the view
    // hides them while this one runs, and an answer replaces them.
    emit(
      state.copyWith(
        entries: () => <ConversationEntry>[
          ...state.entries,
          if (echo != null) UserSaid(echo),
        ],
        status: () => ConversationStatus.running,
        failure: () => null,
        lastTurn: () => TurnRequest(text: text, action: action),
      ),
    );
    final turn = _agentRepository.startTurn(
      text: text,
      action: action,
      // A counter, never a clock or a random source (N-13): the transcript's
      // own length is what a test can predict. `contextId` is omitted on
      // purpose — the server echoes it and resolves nothing from it (ADR-J).
      messageId: 'm-${state.entries.length}',
    );
    try {
      await for (final agentEvent in turn) {
        await _apply(agentEvent, emit);
      }
    } finally {
      if (state.status == ConversationStatus.running) {
        // The turn ended without a terminal status — it stopped mid-flight,
        // or something escaped the stream. Showing what arrived beats
        // leaving the surface spinning forever, and the events that did land
        // are still on screen.
        //
        // `finally`, not a plain statement after the loop. The repository
        // now converts a stream error into an `AgentFailed` event, so
        // nothing SHOULD escape — but "should" is what the status was
        // trusting before, and the cost of being wrong is the whole screen:
        // an exception out of this handler leaves the state at `running`,
        // Bloc reports it to `onError`, and the typing indicator and the
        // disabled composer stay that way until the app is reloaded. There
        // is no state of the world in which a finished turn should still
        // look like it is running, so the exit is unconditional
        // (spec `frontend/0018`).
        emit(state.copyWith(status: () => ConversationStatus.idle));
      }
    }
  }
}
