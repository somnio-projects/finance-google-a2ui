import 'package:equatable/equatable.dart';

/// How a turn ended (spec `client/0003` §8.3).
enum AgentTurnState {
  /// The turn finished and no surface awaits the user.
  completed,

  /// The turn produced a surface the user may act on.
  ///
  /// **A normal terminal state, not an error** (ADR-D D-3, N-11). It is
  /// emitted whenever the turn carried any render intent, which is the common
  /// case for this app — a client that treats it as a failure shows an error
  /// on every successful widget-bearing turn.
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

/// A surface is ready, **while the turn is still running** (ADR-K D-19).
///
/// It names a registered view and carries no payload: the client resolves the
/// view through the same component registry a REST read goes through, and
/// fetches the payload itself. That is what makes the first widget appear
/// before the answer text arrives.
final class AgentSurfaceReady extends AgentEvent {
  /// Creates the event for the surface at [index].
  const AgentSurfaceReady({
    required this.index,
    required this.view,
    required this.options,
  });

  /// Position of this surface in the turn, from zero.
  final int index;

  /// The registered view id the agent chose. Never invented by the client,
  /// and validated against the registry before it is rendered (N-6).
  final String view;

  /// The declared options the agent chose, as query values.
  ///
  /// The server sends them as JSON (`{"top_n": 5}`) and they travel back as
  /// query parameters, so each value is rendered with `toString`. That is a
  /// transport encoding of the server's own choice, not a formatting decision
  /// about a figure — nothing here reaches a label (N-1, N-7).
  final Map<String, String> options;

  @override
  List<Object?> get props => <Object?>[index, view, options];
}

/// The assistant's answer, with every surface of the turn repeated.
final class AgentAnswered extends AgentEvent {
  /// Creates the event.
  const AgentAnswered({required this.text, required this.views});

  /// The answer text, shown verbatim. The backend writes it; the client
  /// never rewrites or reformats it.
  final String text;

  /// Every view id the turn produced, in order. Repeats what the incremental
  /// [AgentSurfaceReady] events already carried, so a consumer that ignores
  /// them still receives everything.
  final List<String> views;

  @override
  List<Object?> get props => <Object?>[text, views];
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
