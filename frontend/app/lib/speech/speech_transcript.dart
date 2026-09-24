import 'package:finance_app/speech/speech_recognizer.dart';

/// One phrase the engine reported, as plain Dart.
///
/// The browser hands these over as a JS object; this is the shape they take
/// the moment they cross out of `dart:js_interop`, so that everything after
/// the crossing is testable on the VM (spec frontend/0023 OD-3).
typedef SpeechPhrase = ({String transcript, bool isFinal});

/// Assemble the whole utterance from the engine's accumulated phrases.
///
/// Extracted from `speech_web.dart` deliberately. That file is the feature's
/// one coverage exemption, and an exemption is only honest while nothing
/// **decidable** hides behind it: this function is the one part of reading an
/// event that can be wrong in a way a test would catch — a missed `trim`, or
/// an `isFinal` that answers for the last phrase rather than for all of them.
///
/// `results` accumulates rather than replacing, and entry zero of each phrase
/// is the engine's best alternative, so joining them is **reading, not
/// computing**: no figure is involved and nothing here is formatted. The
/// phrases are concatenated with no separator because each already carries
/// the spacing the engine heard.
///
/// A session that ends having heard nothing yields an empty, final
/// transcript — the caller shows nothing rather than a blank interim state.
SpeechHeard heardFrom(Iterable<SpeechPhrase> phrases) {
  final words = StringBuffer();
  var isFinal = true;
  for (final phrase in phrases) {
    words.write(phrase.transcript);
    if (!phrase.isFinal) isFinal = false;
  }
  return SpeechHeard(words.toString().trim(), isFinal: isFinal);
}
