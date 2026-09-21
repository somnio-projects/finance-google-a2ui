import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

part 'conversation_entry.dart';
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
  }

  /// The portfolio a surface is rendered for. `current` resolves to the
  /// authenticated caller's own portfolio.
  final String portfolioId;

  final AgentRepository _agentRepository;
  final ViewsRepository _viewsRepository;

  Future<void> _onMessageSent(
    ConversationMessageSent event,
    Emitter<ConversationState> emit,
  ) async {
    _append(emit, UserSaid(event.text), status: ConversationStatus.running);
    final turn = _agentRepository.startTurn(
      text: event.text,
      // Derived from the transcript's own length, never from a clock or a
      // random source: both the device clock and the maths library are absent
      // from this app by rule (N-13), and a counter is what a test can
      // predict. Naming either mechanism here would itself fail
      // `binding_rules_test.dart`, which matches the text, not the intent.
      messageId: 'm-${state.entries.length}',
      // Omitted deliberately. The server echoes `contextId` for correlation
      // and resolves nothing from it (ADR-J D-4); omitting it yields
      // `"contextId": null` on every event, which is not an error. When
      // sessions land (GGU-46) this is where the id will come from.
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

  Future<void> _apply(AgentEvent event, Emitter<ConversationState> emit) async {
    switch (event) {
      case AgentTurnStarted():
        // The running status is already set; nothing is shown for the open.
        emit(state.copyWith(status: () => ConversationStatus.running));
      case AgentSurfaceReady():
        await _fetchSurface(event, emit);
      case AgentAnswered():
        _append(emit, AgentSaid(event.text));
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
    // The intent names a view and carries no payload, so the client fetches
    // it — through the same read path and the same options a `?view=` request
    // uses. The agent picked from the registry; it did not invent a shape.
    final result = await _viewsRepository.fetchPortfolioViews(
      portfolioId: portfolioId,
      views: <String>[event.view],
      options: event.options,
    );
    switch (result) {
      case Ok<RenderedViews>(:final value):
        final payload = value.views[event.view];
        _append(
          emit,
          payload == null
              ? SurfaceUnavailable(
                  view: event.view,
                  message: 'The response carried no payload for this view.',
                )
              : AgentSurface(payload),
        );
      case Err<RenderedViews>(:final failure):
        _append(
          emit,
          SurfaceUnavailable(view: event.view, message: failure.message),
        );
    }
  }

  void _append(
    Emitter<ConversationState> emit,
    ConversationEntry entry, {
    ConversationStatus? status,
  }) {
    final entries = <ConversationEntry>[...state.entries, entry];
    emit(
      status == null
          ? state.copyWith(entries: () => entries)
          : state.copyWith(entries: () => entries, status: () => status),
    );
  }
}
