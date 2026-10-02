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

/// *Try again* on a failed turn: send what the last turn sent (GGU-111).
///
/// Field-less and `const`, like the other events; the request it repeats is
/// read from the state, so nothing here can disagree with the transcript.
final class ConversationRetried extends ConversationEvent {
  /// Creates the event.
  const ConversationRetried();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A person changed one declared option of a surface in the transcript
/// (GGU-113): re-render that surface with the option changed.
///
/// [slot] is the entry's index — entries are only ever appended, so an index
/// names the same surface for the life of the transcript. The option and its
/// value travel **verbatim**: the component read them from the payload's own
/// `inputs[]`, and the backend validates them against the same registry that
/// declared them (ADR-K D-3).
final class ConversationSurfaceEdited extends ConversationEvent {
  /// Creates the event.
  const ConversationSurfaceEdited({
    required this.slot,
    required this.option,
    required this.value,
  });

  /// Which entry of the transcript.
  final int slot;

  /// The declared option's name.
  final String option;

  /// Its new value, as the control produced it.
  final String value;

  @override
  List<Object?> get props => <Object?>[slot, option, value];
}
