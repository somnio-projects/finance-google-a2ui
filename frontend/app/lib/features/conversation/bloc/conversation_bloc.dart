import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:finance_app/features/conversation/bloc/conversation_entry.dart';
import 'package:finance_app/features/conversation/bloc/surface_fetch.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

export 'package:finance_app/features/conversation/bloc/conversation_entry.dart';

part 'conversation_apply.dart';
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
  }

  /// The portfolio a surface is rendered for. `current` resolves to the
  /// authenticated caller's own portfolio.
  final String portfolioId;

  final AgentRepository _agentRepository;
  final ViewsRepository _viewsRepository;

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
    emit(
      state.copyWith(
        entries: () => <ConversationEntry>[
          ...state.entries,
          if (echo != null) UserSaid(echo),
        ],
        suggestions: () => const <Suggestion>[],
        status: () => ConversationStatus.running,
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
    await for (final agentEvent in turn) {
      await _apply(agentEvent, emit);
    }
    if (state.status == ConversationStatus.running) {
      // The stream ended without a terminal status — a turn that stopped
      // mid-flight. Showing what arrived beats leaving the surface spinning
      // forever, and the events that did land are still on screen.
      emit(state.copyWith(status: () => ConversationStatus.idle));
    }
  }
}
