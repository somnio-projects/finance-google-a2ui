import 'package:genui/genui.dart';

/// Events for the landing bloc.
sealed class LandingEvent {
  const LandingEvent();
}

/// The user sent a text message from the form.
final class LandingMessageSent extends LandingEvent {
  const LandingMessageSent(this.text);

  final String text;
}

/// A rendered surface submitted a message (e.g. "Book Now").
final class LandingSurfaceSubmitted extends LandingEvent {
  const LandingSurfaceSubmitted(this.message);

  final ChatMessage message;
}

/// Surfaces were added, updated or removed.
final class LandingSurfacesChanged extends LandingEvent {
  const LandingSurfacesChanged();
}

/// The agent connection reported an error.
final class LandingErrorOccurred extends LandingEvent {
  const LandingErrorOccurred(this.error);

  final Object error;
}

/// Time to rotate the loading placeholder text.
final class LandingLoadingTextAdvanced extends LandingEvent {
  const LandingLoadingTextAdvanced();
}
