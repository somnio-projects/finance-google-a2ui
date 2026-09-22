part of 'voice_input_bloc.dart';

/// Something that asks [VoiceInputBloc] to do work.
///
/// **Neither `const` nor `Equatable`** — the one deviation from ADR-L D-7 in
/// this feature, and it is forced rather than chosen. Both members are
/// field-less, so a `const` constructor is canonicalised at compile time and
/// never runs, which no test can reach and the 100 % line contract (D-11)
/// then cannot be met; and `Equatable` is `@immutable`, so
/// `prefer_const_constructors_in_immutables` would demand the `const` back.
///
/// Value equality also buys nothing here and reads wrong: **two taps are two
/// events** (spec 0022 AC-7), which is the opposite of what equal events
/// suggest. The states below *are* `Equatable`, because those are compared.
sealed class VoiceInputEvent {
  /// Allows subclasses to declare their own constructors.
  VoiceInputEvent();
}

/// The mic was tapped while it was not listening.
final class VoiceInputStarted extends VoiceInputEvent {
  /// Creates the event.
  VoiceInputStarted();
}

/// The stop control was tapped: finish the session, keep what was heard.
final class VoiceInputStopped extends VoiceInputEvent {
  /// Creates the event.
  VoiceInputStopped();
}
