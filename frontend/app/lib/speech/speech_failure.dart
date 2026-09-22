/// Why one dictation session ended without words the person can use.
///
/// An enum rather than a sealed class: every member is a bare kind with no
/// payload, and a `switch` over it is exhaustive by compilation either way —
/// which is the property ADR-L D-8 is actually asking for (spec
/// frontend/0023 §3). Adding a member is a compile error in `voiceNotice`,
/// which is where a new kind must gain its sentence.
enum SpeechFailure {
  /// This build cannot dictate at all: no Web Speech API, or not a browser.
  ///
  /// Reported before a session is ever opened, so nothing was captured and no
  /// permission was requested.
  unavailable,

  /// The person, or the site's own policy, refused the microphone.
  permissionDenied,

  /// The device has no capture hardware the browser can open.
  noMicrophone,

  /// The session opened and ended without hearing anything.
  noSpeech,

  /// The engine could not reach the recognition service.
  ///
  /// Chromium's implementation is server-backed, so dictation needs the
  /// network even though the page is already loaded.
  network,

  /// The session was cut short before it produced a result.
  aborted,

  /// An engine error this client has no sentence of its own for.
  ///
  /// `bad-grammar` and `language-not-supported` land here: both are real
  /// codes, neither is actionable by the person, and inventing advice for
  /// them would be worse than saying plainly that something went wrong.
  unknown,
}

/// The kind a Web Speech `SpeechRecognitionErrorEvent.error` code names.
///
/// The mapping lives here, in pure Dart, rather than in the web binding: it
/// is the one decision in this feature worth getting wrong, and the binding
/// is the one file no test can load (spec frontend/0023 OD-3).
SpeechFailure speechFailureFor(String code) => switch (code) {
  // Two codes for one refusal: `not-allowed` is the person saying no (or a
  // remembered no), `service-not-allowed` is the user agent or a policy
  // refusing on their behalf. Neither is recoverable from inside the page.
  'not-allowed' || 'service-not-allowed' => SpeechFailure.permissionDenied,
  'audio-capture' => SpeechFailure.noMicrophone,
  'no-speech' => SpeechFailure.noSpeech,
  'network' => SpeechFailure.network,
  'aborted' => SpeechFailure.aborted,
  _ => SpeechFailure.unknown,
};
