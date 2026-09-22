import 'package:finance_app/speech/speech_failure.dart';

/// What the mic says when it is idle and an engine exists.
const String voiceIdleTooltip = 'Voice input';

/// What it says while the microphone is open.
const String voiceListeningTooltip = 'Stop dictation';

/// What it says on a build with no engine — before anybody taps it.
const String voiceUnavailableTooltip = 'Voice input unavailable';

/// The sentence shown when a dictation session ends without usable words.
///
/// **These sentences are the client's, and that is not a breach of N-1.**
/// The contract-binding rule keeps the client from writing prose the backend
/// owns; every sentence here is about the *device* — whether this browser has
/// the API, whether the microphone was granted, whether anything was heard.
/// No server knows any of it and no payload field could carry it
/// (spec frontend/0022 OD-5).
///
/// The `switch` is exhaustive over [SpeechFailure], so a new kind is a
/// compile error here rather than a snackbar with nothing in it.
String voiceNotice(SpeechFailure failure) => switch (failure) {
  SpeechFailure.unavailable =>
    'This browser cannot dictate. Chrome, Edge and Safari can. '
        'Type your question instead.',
  SpeechFailure.permissionDenied =>
    'The microphone is blocked for this site. Allow it in your browser, '
        'then tap the mic again.',
  SpeechFailure.noMicrophone => 'No microphone was found on this device.',
  SpeechFailure.noSpeech => 'Nothing was heard. Tap the mic and speak again.',
  SpeechFailure.network =>
    'Speech recognition could not reach its service. Check the connection '
        'and try again.',
  SpeechFailure.aborted => 'Dictation stopped before anything was heard.',
  SpeechFailure.unknown =>
    'Dictation stopped unexpectedly. Try again, or type your question.',
};
