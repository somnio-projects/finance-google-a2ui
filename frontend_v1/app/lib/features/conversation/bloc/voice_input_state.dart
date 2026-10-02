part of 'voice_input_bloc.dart';

/// Where one dictation session is.
enum VoiceInputStatus {
  /// This build has no engine. The mic is drawn, tappable, and says so.
  unavailable,

  /// An engine exists and nothing is being said.
  idle,

  /// The microphone is open.
  listening,
}

/// What the mic button and the composer read.
///
/// The transitions are **named methods rather than a getter-parameter
/// `copyWith`**: this state has four fields and exactly four legal moves, and
/// naming them makes the bloc read as the machine it is. A `copyWith` would
/// also let a caller change `notices` without a failure, which is the one
/// invariant this class has.
final class VoiceInputState extends Equatable {
  /// Creates a state.
  const VoiceInputState({
    this.status = VoiceInputStatus.idle,
    this.transcript = '',
    this.failure,
    this.notices = 0,
  });

  /// Whether an engine exists, and whether it is open.
  final VoiceInputStatus status;

  /// Everything heard in the current session, as the engine reads it now.
  final String transcript;

  /// Why the last session ended without words, when it did.
  final SpeechFailure? failure;

  /// How many notices have been raised.
  ///
  /// **A sentence is not a state change**, and this counter is what makes it
  /// one. Two denied permissions in a row produce two equal states, which
  /// `BlocListener` fires on once — so the second tap would be silent, which
  /// is exactly the defect spec 0021 OD-2 recorded. The listener keys on this
  /// instead (spec 0022 OD-4, AC-7).
  final int notices;

  /// The session is opening: clear the last one and start listening.
  VoiceInputState listening() =>
      VoiceInputState(status: VoiceInputStatus.listening, notices: notices);

  /// The engine reports [heard] — the whole utterance, not a delta.
  VoiceInputState hearing(String heard) =>
      VoiceInputState(status: status, transcript: heard, notices: notices);

  /// The session ended without usable words, and the person is told why.
  ///
  /// An unavailable engine stays unavailable; anything else returns to idle,
  /// so the button is ready for the next tap.
  VoiceInputState noticing(SpeechFailure reason) => VoiceInputState(
    status: status == VoiceInputStatus.unavailable
        ? VoiceInputStatus.unavailable
        : VoiceInputStatus.idle,
    transcript: transcript,
    failure: reason,
    notices: notices + 1,
  );

  /// The session ended normally; what was heard stays in the field.
  VoiceInputState settled() => VoiceInputState(
    transcript: transcript,
    failure: failure,
    notices: notices,
  );

  @override
  List<Object?> get props => <Object?>[status, transcript, failure, notices];
}
