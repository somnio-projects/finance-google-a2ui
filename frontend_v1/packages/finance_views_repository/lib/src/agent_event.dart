import 'package:a2ui_v1/a2ui_v1.dart';
import 'package:equatable/equatable.dart';

/// How a turn ended (spec `client/0003` §8.3).
enum AgentTurnState {
  /// The turn finished and no surface awaits the user.
  completed,

  /// The turn produced a surface the user may act on.
  ///
  /// **A normal terminal state, not an error** (ADR-D D-3, N-11). It is
  /// emitted whenever the turn carried any surface, which is the common case
  /// for this app — a client that treats it as a failure shows an error on
  /// every successful widget-bearing turn.
  inputRequired,

  /// The turn could not be completed; an [AgentFailed] follows it.
  failed,
}

/// One thing that happened during an agent turn.
///
/// `sealed`, so a `switch` over it is exhaustive and a new event kind is a
/// compile error in every incomplete handler — the same contract `AppFailure`
/// keeps (ADR-L D-8).
sealed class AgentEvent extends Equatable {
  /// Allows subclasses to declare `const` constructors.
  const AgentEvent();

  @override
  List<Object?> get props => <Object?>[];
}

/// The turn opened and is running.
final class AgentTurnStarted extends AgentEvent {
  /// Creates the event.
  const AgentTurnStarted();
}

/// A2UI v1.0 messages, **while the turn is still running** (ADR-M D-3).
///
/// One `artifact-update` carries one `DataPart` per surface or function
/// response; its messages arrive here already decoded, one outcome each, so a
/// malformed message is reported by the processor and its neighbours still
/// apply (the extension spec's processing rules). Unlike the v0.9 wire there
/// is nothing left to fetch: the payload is in the surface's data model.
final class AgentSurfaceMessages extends AgentEvent {
  /// Creates the event for [messages], in wire order.
  const AgentSurfaceMessages(this.messages);

  /// The decoded messages of every A2UI part of the artifact.
  final List<Decoded> messages;

  @override
  List<Object?> get props => <Object?>[messages];
}

/// One follow-up the turn recommends (spec backend/0029). The client shows
/// [label] and, on the v1.0 wire, sends that same text back as an ordinary
/// text part — a chip lives outside any surface, so no A2UI message pretends
/// one exists (ADR-M D-7). [key] is kept for identity and tests.
final class Suggestion extends Equatable {
  /// Creates the suggestion.
  const Suggestion({required this.key, required this.label});

  /// The registered suggestion key.
  final String key;

  /// The chip's words, verbatim.
  final String label;

  @override
  List<Object?> get props => <Object?>[key, label];
}

/// The assistant's answer and the follow-ups it recommends.
final class AgentAnswered extends AgentEvent {
  /// Creates the event.
  const AgentAnswered({
    required this.text,
    this.suggestions = const <Suggestion>[],
  });

  /// The answer text, shown verbatim. The backend writes it; the client
  /// never rewrites or reformats it.
  final String text;

  /// The follow-ups the turn recommends, in the backend's order (N-10).
  final List<Suggestion> suggestions;

  @override
  List<Object?> get props => <Object?>[text, suggestions];
}

/// The turn reached a terminal state.
final class AgentTurnEnded extends AgentEvent {
  /// Creates the event.
  const AgentTurnEnded(this.state);

  /// The terminal state.
  final AgentTurnState state;

  @override
  List<Object?> get props => <Object?>[state];
}

/// Why the turn failed.
///
/// **Arrives after [AgentTurnEnded]**, not before (spec `client/0003` §8.5):
/// the stream must be read to its end or the reason is lost and the user is
/// shown "failed" with no explanation.
final class AgentFailed extends AgentEvent {
  /// Creates the event.
  const AgentFailed({required this.code, required this.message});

  /// A safe, stable identifier — never provider text.
  final String code;

  /// Safe, human-readable text the backend wrote.
  final String message;

  @override
  List<Object?> get props => <Object?>[code, message];
}
