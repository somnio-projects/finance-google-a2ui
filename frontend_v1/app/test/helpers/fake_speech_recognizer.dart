import 'dart:async';

import 'package:finance_app/speech/speech_recognizer.dart';

/// A dictation engine a test drives, in the three shapes tests need.
///
/// The real engine is a browser API no VM can start, which is exactly why
/// `VoiceInputBloc` takes the seam rather than the browser (spec 0022 OD-2).
class FakeSpeechRecognizer extends SpeechRecognizer {
  /// An engine that reports [_script] and then ends the session.
  FakeSpeechRecognizer.scripted(this._script) : isSupported = true;

  /// An engine whose session stays open until [say]/[stop] end it.
  FakeSpeechRecognizer.live() : _script = null, isSupported = true;

  /// A platform with no engine at all.
  FakeSpeechRecognizer.absent() : _script = null, isSupported = false;

  final List<SpeechEvent>? _script;
  final StreamController<SpeechEvent> _open = StreamController<SpeechEvent>();

  @override
  final bool isSupported;

  /// How many sessions were opened.
  int starts = 0;

  /// How many times the engine was asked to finish.
  int stops = 0;

  @override
  Stream<SpeechEvent> start() {
    starts++;
    final script = _script;
    return script == null
        ? _open.stream
        : Stream<SpeechEvent>.fromIterable(script);
  }

  @override
  Future<void> stop() async {
    stops++;
    await finish();
  }

  /// Reports [event] on an open session.
  void say(SpeechEvent event) => _open.add(event);

  /// Ends an open session the way the engine's `end` handler does.
  Future<void> finish() async {
    if (!_open.isClosed) await _open.close();
  }
}
