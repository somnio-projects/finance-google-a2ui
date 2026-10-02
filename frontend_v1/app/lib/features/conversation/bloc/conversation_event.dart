part of 'conversation_bloc.dart';

/// Something that happens to the conversation.
sealed class ConversationEvent extends Equatable {
  /// Allows subclasses to declare `const` constructors.
  const ConversationEvent();
}

/// The user sent [text].
final class ConversationMessageSent extends ConversationEvent {
  /// Creates the event.
  const ConversationMessageSent(this.text);

  /// The message, as typed.
  final String text;

  @override
  List<Object?> get props => <Object?>[text];
}

/// The user tapped a follow-up chip.
///
/// On the v1.0 wire a chip is sent as **its own words in an ordinary text
/// part** (ADR-M D-7): a chip lives outside any surface, so no A2UI message
/// pretends one exists.
final class ConversationSuggestionTapped extends ConversationEvent {
  /// Creates the event for [suggestion].
  const ConversationSuggestionTapped(this.suggestion);

  /// The chip.
  final Suggestion suggestion;

  @override
  List<Object?> get props => <Object?>[suggestion];
}

/// The component [componentId] of [surfaceId] raised [request] — a bar of
/// the waterfall, sent as a v1.0 `action` (ADR-M D-7, AC-6).
final class ConversationActionSent extends ConversationEvent {
  /// Creates the event.
  const ConversationActionSent({
    required this.surfaceId,
    required this.componentId,
    required this.request,
  });

  /// The surface the tap happened on.
  final String surfaceId;

  /// The component that raised it.
  final String componentId;

  /// The action's name and its context, as the component published them.
  final SurfaceActionRequest request;

  @override
  List<Object?> get props => <Object?>[surfaceId, componentId, request];
}

/// *Try again* on a failed turn: the same request once more (GGU-111).
final class ConversationRetried extends ConversationEvent {
  /// Creates the event.
  const ConversationRetried();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The person changed one declared [option] of [componentId] on
/// [surfaceId] to [value] — sent as `callAgentFunction("renderView")`, never
/// through the model (ADR-M D-6, AC-5).
final class ConversationSurfaceEdited extends ConversationEvent {
  /// Creates the event.
  const ConversationSurfaceEdited({
    required this.surfaceId,
    required this.componentId,
    required this.option,
    required this.value,
  });

  /// The surface being edited.
  final String surfaceId;

  /// The component whose options change.
  final String componentId;

  /// The declared option's name.
  final String option;

  /// Its new value, verbatim.
  final String value;

  @override
  List<Object?> get props => <Object?>[surfaceId, componentId, option, value];
}
