part of 'conversation_bloc.dart';

/// One thing the conversation shows, in arrival order.
///
/// `sealed`, so the view's `switch` is exhaustive and a new entry kind is a
/// compile error rather than a blank space on screen.
///
/// Note there is deliberately **no `props` here**. Every subclass overrides
/// it, so a base implementation would be a line no test can reach — the same
/// dead-code coverage gap `.claude/rules/frontend/testing.md` records from the
/// first build of this app. `Equatable` declares it abstract; leaving it that
/// way is what keeps the file at 100 %.
sealed class ConversationEntry extends Equatable {
  /// Allows subclasses to declare `const` constructors.
  const ConversationEntry();
}

/// What the user asked.
final class UserSaid extends ConversationEntry {
  /// Records [text], shown back verbatim.
  const UserSaid(this.text);

  /// The message the user typed.
  final String text;

  @override
  List<Object?> get props => <Object?>[text];
}

/// What the agent answered, in words.
final class AgentSaid extends ConversationEntry {
  /// Records [text], rendered verbatim — the client never rewrites it.
  const AgentSaid(this.text);

  /// The answer the backend wrote.
  final String text;

  @override
  List<Object?> get props => <Object?>[text];
}

/// A surface the agent asked for, with the payload already fetched.
///
/// It carries the payload and **not** a widget: which component renders it is
/// decided by the one `ComponentRegistry`, at build time, exactly as it is for
/// a surface the user navigated to. There is no second rendering path.
final class AgentSurface extends ConversationEntry {
  /// Records [payload] for the view the agent chose.
  const AgentSurface(this.payload);

  /// The rendered projection, shaped entirely by the backend.
  final ViewPayload payload;

  @override
  List<Object?> get props => <Object?>[payload];
}

/// A surface the agent asked for that could not be fetched.
///
/// Shown rather than dropped: the turn succeeded and the answer text is still
/// worth reading, so one missing widget degrades that surface alone.
final class SurfaceUnavailable extends ConversationEntry {
  /// Records that [view] could not be shown, because of [message].
  const SurfaceUnavailable({required this.view, required this.message});

  /// The view id the agent chose.
  final String view;

  /// Safe text explaining why — the backend's own, or this app's wording.
  final String message;

  @override
  List<Object?> get props => <Object?>[view, message];
}
