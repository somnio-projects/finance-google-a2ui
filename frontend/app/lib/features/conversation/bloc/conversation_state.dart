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
    this.failure,
  });

  /// Whether a turn is running.
  final ConversationStatus status;

  /// Everything said and shown so far, oldest first.
  final List<ConversationEntry> entries;

  /// Why the last turn failed, when it did.
  ///
  /// Carries the backend's own safe `code` and `message` — never a library
  /// string and never a stack trace.
  final AgentFailed? failure;

  /// Copies this state, replacing only the fields whose getter is supplied.
  ///
  /// Each parameter is a getter rather than a value so that passing `null`
  /// *retains* the old value while `() => null` *clears* it.
  ConversationState copyWith({
    ConversationStatus Function()? status,
    List<ConversationEntry> Function()? entries,
    AgentFailed? Function()? failure,
  }) => ConversationState(
    status: status != null ? status() : this.status,
    entries: entries != null ? entries() : this.entries,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => <Object?>[status, entries, failure];
}
