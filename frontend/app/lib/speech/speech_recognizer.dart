import 'package:finance_app/speech/speech_failure.dart';

/// Something a dictation engine reported during one session.
///
/// Sealed, so a handler that forgets a case does not compile (ADR-L D-8).
/// There is no "session ended" member: the stream closing **is** the end, and
/// a second way of saying so is a second thing to keep in step.
sealed class SpeechEvent {
  /// Allows subclasses to declare `const` constructors.
  const SpeechEvent();
}

/// Words the engine has heard so far in this session.
///
/// [transcript] is always the whole utterance, never a delta: the Web Speech
/// API re-reports the growing result, and a client that appended deltas would
/// be assembling a sentence the engine has already assembled.
final class SpeechHeard extends SpeechEvent {
  /// Creates a heard-so-far event.
  const SpeechHeard(this.transcript, {required this.isFinal});

  /// Everything heard in this session, as the engine currently reads it.
  final String transcript;

  /// Whether the engine has committed to this reading.
  ///
  /// An interim transcript can still change; a final one cannot. Both are
  /// shown, which is what makes dictation feel alive (spec 0023 AC-3).
  final bool isFinal;
}

/// The session ended without words the person can use.
final class SpeechFailed extends SpeechEvent {
  /// Creates a failure event.
  const SpeechFailed(this.failure);

  /// Which way it failed. Every kind has a sentence in `voiceNotice`.
  final SpeechFailure failure;
}

/// One dictation engine, as everything above it sees the browser.
///
/// The seam exists so that no bloc and no widget touches `dart:js_interop`:
/// the implementation is chosen by a conditional import in `bootstrap.dart`
/// and published to the tree, and every test drives a fake through this
/// interface (spec frontend/0023 OD-2, ADR-L D-2).
abstract class SpeechRecognizer {
  /// Allows implementations to declare `const` constructors.
  const SpeechRecognizer();

  /// Whether this build can dictate at all.
  ///
  /// False is a **state the UI shows**, not an error it hides: the mic still
  /// answers a tap and says why (spec 0023 AC-1).
  bool get isSupported;

  /// Opens one session and reports it until the stream closes.
  ///
  /// The stream ends when the engine ends — after a final transcript, after
  /// [stop], or after a failure. It never ends silently mid-utterance.
  Stream<SpeechEvent> start();

  /// Asks the engine to finish the current session and keep what it heard.
  ///
  /// Distinct from abandoning it: `stop` is the person saying "that is my
  /// question", so the last result still arrives before the stream closes.
  Future<void> stop();
}

/// The recognizer a build with no Web Speech API gets.
///
/// It reports one [SpeechFailed] and closes, so the caller's single code path
/// works unchanged: an unsupported platform is a stated outcome rather than a
/// branch every caller has to remember (spec 0023 AC-1).
class UnsupportedSpeechRecognizer extends SpeechRecognizer {
  /// Creates the honest no-op recognizer.
  const UnsupportedSpeechRecognizer();

  @override
  bool get isSupported => false;

  @override
  Stream<SpeechEvent> start() =>
      Stream<SpeechEvent>.value(const SpeechFailed(SpeechFailure.unavailable));

  @override
  Future<void> stop() async {}
}
