import 'package:equatable/equatable.dart';

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

/// An A2UI v1.0 surface the agent created, by id (ADR-M D-3).
///
/// It carries the **id** and not the surface: the surface lives in
/// `ConversationState.surfaces`, where the processor updates it in place as
/// `updateDataModel` and `updateComponents` arrive — an edit re-renders the
/// same entry rather than appending a new one. Which widgets draw it is
/// decided by the one `ComponentRegistry`, at build time, exactly as for a
/// surface the user navigated to; there is no second rendering path.
final class AgentSurface extends ConversationEntry {
  /// Records the surface [surfaceId].
  const AgentSurface(this.surfaceId);

  /// The `createSurface.surfaceId`.
  final String surfaceId;

  @override
  List<Object?> get props => <Object?>[surfaceId];
}
