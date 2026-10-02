import 'package:finance_app/speech/speech_recognizer.dart';

/// The recognizer for a target with no `dart:js_interop`.
///
/// Chosen by the conditional import in `bootstrap.dart` for everything that is
/// not compiled to JavaScript or WebAssembly — which today means the Dart VM
/// the test suite runs on, and any native build somebody adds later. It is a
/// declared state, not a degraded one: the mic says so (spec 0022 OD-2).
SpeechRecognizer createSpeechRecognizer() =>
    const UnsupportedSpeechRecognizer();
