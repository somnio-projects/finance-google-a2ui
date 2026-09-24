import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:finance_app/speech/speech_failure.dart';
import 'package:finance_app/speech/speech_recognizer.dart';

part 'voice_input_event.dart';
part 'voice_input_state.dart';

/// Owns one dictation session, and nothing else.
///
/// It does not know what a question is, it never reaches the agent, and it
/// never formats or computes anything — a transcript is a string the person
/// said. What it produces goes into the composer's field, from where the
/// existing send path takes over unchanged (spec frontend/0023 OD-1, AC-8).
///
/// The browser is behind [SpeechRecognizer], so this class is driven by a
/// fake in every test and `dart:js_interop` appears nowhere near it
/// (spec 0023 OD-2).
class VoiceInputBloc extends Bloc<VoiceInputEvent, VoiceInputState> {
  /// Creates a bloc over [recognizer].
  ///
  /// The initial status is read from the engine rather than assumed: a build
  /// that cannot dictate says so on the button from the first frame, before
  /// anybody taps it.
  VoiceInputBloc({required SpeechRecognizer recognizer})
    : _recognizer = recognizer,
      super(
        VoiceInputState(
          status: recognizer.isSupported
              ? VoiceInputStatus.idle
              : VoiceInputStatus.unavailable,
        ),
      ) {
    on<VoiceInputStarted>(_onStarted);
    on<VoiceInputStopped>(_onStopped);
  }

  final SpeechRecognizer _recognizer;

  Future<void> _onStarted(
    VoiceInputStarted event,
    Emitter<VoiceInputState> emit,
  ) async {
    // A tap on a mic that cannot listen is still a tap, and it gets a
    // sentence (spec 0021 OD-2, applied one layer in).
    if (state.status == VoiceInputStatus.unavailable) {
      emit(state.noticing(SpeechFailure.unavailable));
      return;
    }
    // A second start while one session runs is the button being tapped twice;
    // the engine would throw on it, and there is nothing to report.
    if (state.status == VoiceInputStatus.listening) return;
    emit(state.listening());
    await for (final heard in _recognizer.start()) {
      switch (heard) {
        case SpeechHeard(:final transcript):
          emit(state.hearing(transcript));
        case SpeechFailed(:final failure):
          emit(state.noticing(failure));
      }
    }
    // The engine ended the session. A failure already moved the status, so
    // this is the ordinary ending — the person stopped, or the utterance did.
    if (state.status == VoiceInputStatus.listening) emit(state.settled());
  }

  Future<void> _onStopped(
    VoiceInputStopped event,
    Emitter<VoiceInputState> emit,
  ) => _recognizer.stop();
}
