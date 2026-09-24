part of 'conversation_bloc.dart';

/// Something that asks [ConversationBloc] to do work.
sealed class ConversationEvent extends Equatable {
  /// Allows subclasses to declare `const` constructors.
  const ConversationEvent();
}

/// Asks the agent [text] and streams the turn that answers it.
final class ConversationMessageSent extends ConversationEvent {
  /// Sends [text] to the agent.
  const ConversationMessageSent(this.text);

  /// What the user typed. Sent verbatim; the client adds no prompt of its own.
  final String text;

  @override
  List<Object?> get props => <Object?>[text];
}

/// A follow-up chip was tapped (spec frontend/0011 OD-3).
///
/// The label echoes as the user's turn; the **key** is what travels, through
/// `ask.suggested.v1` — the client never sends the chip's words as text.
final class ConversationSuggestionTapped extends ConversationEvent {
  /// Creates the event.
  const ConversationSuggestionTapped(this.suggestion);

  /// The chip, as the backend published it.
  final Suggestion suggestion;

  @override
  List<Object?> get props => <Object?>[suggestion];
}

/// A surface sent one of its declared actions (spec frontend/0011 OD-4).
final class ConversationActionSent extends ConversationEvent {
  /// Creates the event.
  const ConversationActionSent(this.request);

  /// The registered action and its published scalars.
  final SurfaceActionRequest request;

  @override
  List<Object?> get props => <Object?>[request.action, request.args];
}
