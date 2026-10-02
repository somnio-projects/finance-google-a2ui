import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:finance_app/a2ui/action_clock.dart';
import 'package:finance_app/a2ui/surface_edit_state.dart';
import 'package:finance_app/features/conversation/bloc/conversation_entry.dart';
import 'package:finance_views_repository/finance_views_repository.dart';

export 'package:finance_app/a2ui/surface_edit_state.dart';
export 'package:finance_app/features/conversation/bloc/conversation_entry.dart';

part 'conversation_apply.dart';
part 'conversation_edit.dart';
part 'conversation_event.dart';
part 'conversation_state.dart';
part 'turn_request.dart';

/// Runs an agent turn on the A2UI **v1.0** wire and turns it into things to
/// show, as they arrive (ADR-M, spec `frontend_v1/0001`).
///
/// The bloc talks to one repository and to nothing else. It performs no
/// arithmetic and no formatting: the answer text is the backend's, and a
/// surface's payload is the projection the backend shaped (N-1, N-2).
///
/// **Surfaces are drawn while the turn is still running** (ADR-K D-19):
/// each `artifact-update` is applied by the [SurfaceProcessor] the moment it
/// lands, so the first widget appears before the answer text. Unlike v0.9
/// there is no second request — the payload is in the surface's data model.
class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  /// Creates a bloc over the agent repository.
  ///
  /// [catalogId] names the catalog a `renderView` call is resolved in when a
  /// surface did not name one; [clock] stamps an `action`.
  ConversationBloc({
    required AgentRepository agentRepository,
    required this.catalogId,
    ActionClock clock = const ActionClock(),
  }) : _agentRepository = agentRepository,
       _clock = clock,
       super(const ConversationState()) {
    on<ConversationMessageSent>(_onMessageSent);
    on<ConversationSuggestionTapped>(_onSuggestionTapped);
    on<ConversationActionSent>(_onActionSent);
    on<ConversationRetried>(_onRetried);
    on<ConversationSurfaceEdited>(_onSurfaceEdited);
  }

  /// The default catalog of every `callAgentFunction` this bloc sends.
  final String catalogId;

  final AgentRepository _agentRepository;
  final ActionClock _clock;
  final SurfaceProcessor _processor = const SurfaceProcessor();

  /// `functionCallId` → the edit key it answers, while the call is open.
  final Map<String, String> _openCalls = <String, String>{};

  /// Edit key → the newest call for it, so a slow answer cannot overwrite a
  /// newer edit's state (the rule `OrderTicketBloc` keeps).
  final Map<String, String> _newestCall = <String, String>{};

  /// Edit key → the options the newest edit asked for, so a second edit made
  /// before the first is answered merges onto it (spec 0026 OD-3).
  final Map<String, Map<String, Object?>> _intent =
      <String, Map<String, Object?>>{};

  int _calls = 0;

  Future<void> _onMessageSent(
    ConversationMessageSent event,
    Emitter<ConversationState> emit,
  ) => _run(emit, echo: event.text, text: event.text);

  Future<void> _onSuggestionTapped(
    ConversationSuggestionTapped event,
    Emitter<ConversationState> emit,
  ) => _run(emit, echo: event.suggestion.label, text: event.suggestion.label);

  Future<void> _onActionSent(
    ConversationActionSent event,
    Emitter<ConversationState> emit,
  ) => _run(
    emit,
    messages: <RendererMessage>[
      ActionMessage(
        name: event.request.action,
        surfaceId: event.surfaceId,
        sourceComponentId: event.componentId,
        timestamp: _clock.now(),
        context: event.request.args,
      ),
    ],
  );

  /// The same request once more, with no echo: the bubble that asked is
  /// already on screen (GGU-111 AC-1). Nothing to repeat is a no-op.
  Future<void> _onRetried(
    ConversationRetried event,
    Emitter<ConversationState> emit,
  ) async {
    final last = state.lastTurn;
    if (last == null) return;
    await _run(emit, text: last.text, messages: last.messages);
  }

  /// One turn, whatever opened it: a typed sentence, a chip, or a surface's
  /// tap. [echo] is what the transcript shows as the user's turn; a bar tap
  /// shows nothing and lets the answer speak (spec frontend/0011 OD-3, OD-4).
  Future<void> _run(
    Emitter<ConversationState> emit, {
    String? echo,
    String? text,
    List<RendererMessage> messages = const <RendererMessage>[],
  }) async {
    // The chips are NOT cleared here: they survive a failed turn (GGU-111
    // AC-2); the view hides them while this one runs.
    emit(
      state.copyWith(
        entries: () => <ConversationEntry>[
          ...state.entries,
          if (echo != null) UserSaid(echo),
        ],
        status: () => ConversationStatus.running,
        failure: () => null,
        lastTurn: () => TurnRequest(text: text, messages: messages),
      ),
    );
    // A counter, never a clock or a random source (N-13).
    final turn = _agentRepository.startTurn(
      text: text,
      messages: messages,
      messageId: 'm-${state.entries.length}',
    );
    try {
      await for (final agentEvent in turn) {
        _apply(agentEvent, emit);
      }
    } finally {
      // A turn that ended without a terminal status must not look like it
      // is still running (spec `frontend/0018`).
      if (state.status == ConversationStatus.running) {
        emit(state.copyWith(status: () => ConversationStatus.idle));
      }
    }
  }
}
