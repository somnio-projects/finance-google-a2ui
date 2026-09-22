import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:finance_app/speech/speech_failure.dart';
import 'package:finance_app/speech/speech_recognizer.dart';
import 'package:finance_app/speech/speech_transcript.dart';
import 'package:web/web.dart' as web;

/// The recognizer for a build running in a browser.
///
/// Chosen by the conditional import in `bootstrap.dart` (spec 0023 OD-2).
SpeechRecognizer createSpeechRecognizer() => WebSpeechRecognizer();

/// Dictation over the browser's Web Speech API.
///
/// **This file is the one coverage exemption this feature adds, and the
/// reason is mechanical**: a library importing `dart:js_interop` cannot be
/// compiled for the Dart VM, so `flutter test` can never load it and lcov can
/// never write a record for it (spec frontend/0023 OD-3). Everything that
/// could be decided elsewhere has been moved elsewhere — the error-code
/// mapping is in `speech_failure.dart`, assembling the utterance is in
/// `speech_transcript.dart` and the state machine is in `VoiceInputBloc`,
/// all three at 100 %. What is left is construction, four callback
/// registrations, and copying fields out of a JS object into records. It is
/// compiled for real by `flutter build web --release`, which `frontend-ci`
/// runs on every pull request; that is the check this file actually has.
class WebSpeechRecognizer extends SpeechRecognizer {
  /// Creates a recognizer over the browser's engine.
  WebSpeechRecognizer();

  web.SpeechRecognition? _session;

  @override
  bool get isSupported => _constructor() != null;

  @override
  Stream<SpeechEvent> start() {
    final constructor = _constructor();
    if (constructor == null) {
      return Stream<SpeechEvent>.value(
        const SpeechFailed(SpeechFailure.unavailable),
      );
    }
    final events = StreamController<SpeechEvent>();
    // One utterance per tap (spec 0023 OD-7): `continuous` would hold the
    // microphone open until something closed it, and a forgotten tab with an
    // open microphone is not a thing to ship. `interimResults` is what makes
    // the words appear while they are still being said (AC-3).
    final session = _session =
        constructor.callAsConstructor<web.SpeechRecognition>()
          ..continuous = false
          ..interimResults = true
          // `lang` is deliberately not set: it defaults to the document's
          // `<html lang>`, which the bundle now declares (spec 0023 OD-9).
          ..onresult = ((web.SpeechRecognitionEvent event) {
            events.add(_heard(event));
          }).toJS
          ..onerror = ((web.SpeechRecognitionErrorEvent event) {
            events.add(SpeechFailed(speechFailureFor(event.error)));
          }).toJS
          // `end` fires after every ending, including after `error`, so closing
          // here is the single exit and the stream cannot be left open.
          ..onend = ((web.Event event) {
            _session = null;
            // Nobody awaits a stream closing; `dispose`-shaped work is the
            // same case `ConversationPage` documents.
            unawaited(events.close());
          }).toJS;
    // The subscription going away without a `stop` means the caller
    // abandoned the session; `abort` is the ending that keeps no result.
    events.onCancel = () async => session.abort();
    session.start();
    return events.stream;
  }

  @override
  Future<void> stop() async => _session?.stop();
}

/// The engine's constructor, under either of the two names browsers use.
///
/// Safari exposes only the `webkit`-prefixed one; Firefox exposes neither,
/// which is what `isSupported` reports as false.
JSFunction? _constructor() {
  for (final name in const <String>[
    'SpeechRecognition',
    'webkitSpeechRecognition',
  ]) {
    if (globalContext.has(name)) {
      return globalContext.getProperty<JSFunction>(name.toJS);
    }
  }
  return null;
}

/// Copy the engine's accumulated phrases out of the JS event.
///
/// The *reading* of them — concatenation, trimming, whether the whole
/// utterance is final — is `heardFrom`, which is plain Dart and is tested.
/// This is only the crossing: a loop over a JS list, producing records.
SpeechHeard _heard(web.SpeechRecognitionEvent event) {
  final results = event.results;
  return heardFrom(<SpeechPhrase>[
    for (var index = 0; index < results.length; index++)
      (
        transcript: results.item(index).item(0).transcript,
        isFinal: results.item(index).isFinal,
      ),
  ]);
}
