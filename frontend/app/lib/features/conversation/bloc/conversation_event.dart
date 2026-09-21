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
