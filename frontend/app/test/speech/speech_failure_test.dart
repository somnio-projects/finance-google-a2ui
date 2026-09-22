import 'package:finance_app/speech/speech_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('speechFailureFor (spec frontend/0022 AC-6)', () {
    // Every code the Web Speech specification defines, so the table is a
    // statement about the API rather than about the ones we happened to hit.
    const codes = <String, SpeechFailure>{
      'not-allowed': SpeechFailure.permissionDenied,
      'service-not-allowed': SpeechFailure.permissionDenied,
      'audio-capture': SpeechFailure.noMicrophone,
      'no-speech': SpeechFailure.noSpeech,
      'network': SpeechFailure.network,
      'aborted': SpeechFailure.aborted,
      'bad-grammar': SpeechFailure.unknown,
      'language-not-supported': SpeechFailure.unknown,
    };

    codes.forEach((code, expected) {
      test('reads "$code" as ${expected.name}', () {
        expect(speechFailureFor(code), expected);
      });
    });

    test('reads a code it has never seen as unknown, not as a refusal', () {
      // The dangerous wrong answer here is `permissionDenied`: it would tell
      // somebody to unblock a microphone that was never blocked.
      expect(speechFailureFor('some-future-code'), SpeechFailure.unknown);
      expect(speechFailureFor(''), SpeechFailure.unknown);
    });
  });
}
