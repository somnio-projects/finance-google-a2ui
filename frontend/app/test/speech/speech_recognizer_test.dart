import 'package:finance_app/speech/speech_failure.dart';
import 'package:finance_app/speech/speech_recognizer.dart';
import 'package:finance_app/speech/speech_stub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnsupportedSpeechRecognizer (spec frontend/0023 AC-1)', () {
    const recognizer = UnsupportedSpeechRecognizer();

    test('says so before anybody opens a session', () {
      expect(recognizer.isSupported, isFalse);
    });

    test('answers a session with one stated failure and closes', () async {
      // Not an empty stream and not a thrown error: the caller has ONE code
      // path, and an unsupported platform travels down it as a value.
      await expectLater(
        recognizer.start(),
        emitsInOrder(<Object>[
          isA<SpeechFailed>().having(
            (event) => event.failure,
            'failure',
            SpeechFailure.unavailable,
          ),
          emitsDone,
        ]),
      );
    });

    test('accepts a stop it has nothing to stop', () async {
      await expectLater(recognizer.stop(), completes);
    });
  });

  group('SpeechHeard', () {
    test('carries the whole utterance so far, never a delta', () {
      // Built the way an engine builds them — from strings it has just read
      // — because the contract under test is that each one REPLACES the
      // last rather than extending it. `VoiceInputListener` relies on that.
      final readings = <String>['how did', 'how did my portfolio do'];
      final heard = readings
          .map((words) => SpeechHeard(words, isFinal: words == readings.last))
          .toList();
      expect(heard.map((event) => event.transcript), readings);
      expect(heard.first.isFinal, isFalse);
      expect(heard.last.isFinal, isTrue);
    });
  });

  group('createSpeechRecognizer', () {
    test('is the unsupported engine on the VM the suite runs on', () {
      // The conditional import in `bootstrap.dart` resolves to
      // `speech_stub.dart` off the web, and this is that promise asserted
      // rather than assumed.
      expect(createSpeechRecognizer(), isA<UnsupportedSpeechRecognizer>());
      expect(createSpeechRecognizer().isSupported, isFalse);
    });
  });
}
