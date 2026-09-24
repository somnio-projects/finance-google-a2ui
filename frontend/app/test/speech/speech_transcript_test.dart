import 'package:finance_app/speech/speech_recognizer.dart';
import 'package:finance_app/speech/speech_transcript.dart';
import 'package:flutter_test/flutter_test.dart';

/// `heardFrom` is the part of reading a recognition event that can be wrong,
/// which is why it lives outside `speech_web.dart` — the one file lcov can
/// never see (spec frontend/0023 OD-3). These are the cases the browser
/// actually produces: one interim phrase, several accumulated phrases, a
/// mixed batch, and a session that heard nothing.
void main() {
  group('heardFrom', () {
    test('reports a single interim phrase as not final', () {
      final heard = heardFrom(const <SpeechPhrase>[
        (transcript: 'what moved my', isFinal: false),
      ]);

      expect(heard.transcript, 'what moved my');
      expect(heard.isFinal, isFalse);
    });

    test('joins accumulated phrases in the order the engine reported', () {
      final heard = heardFrom(const <SpeechPhrase>[
        (transcript: 'what moved ', isFinal: true),
        (transcript: 'my portfolio today', isFinal: true),
      ]);

      expect(heard.transcript, 'what moved my portfolio today');
      expect(heard.isFinal, isTrue);
    });

    test('is final only when every phrase is', () {
      final heard = heardFrom(const <SpeechPhrase>[
        (transcript: 'what moved ', isFinal: true),
        (transcript: 'my portfolio', isFinal: false),
      ]);

      expect(heard.isFinal, isFalse);
    });

    test('a later final phrase does not make an earlier interim one final', () {
      // The regression this guards: answering `isFinal` from the last phrase
      // rather than from all of them would commit an utterance the engine can
      // still change.
      final heard = heardFrom(const <SpeechPhrase>[
        (transcript: 'what moved ', isFinal: false),
        (transcript: 'my portfolio', isFinal: true),
      ]);

      expect(heard.isFinal, isFalse);
    });

    test('trims the engine leading and trailing spacing', () {
      final heard = heardFrom(const <SpeechPhrase>[
        (transcript: '  what moved my portfolio  ', isFinal: true),
      ]);

      expect(heard.transcript, 'what moved my portfolio');
    });

    test('a session that heard nothing is empty and final', () {
      final heard = heardFrom(const <SpeechPhrase>[]);

      expect(heard.transcript, isEmpty);
      expect(heard.isFinal, isTrue);
    });

    test('returns a SpeechHeard, so the caller handles one event kind', () {
      expect(
        heardFrom(const <SpeechPhrase>[(transcript: 'x', isFinal: true)]),
        isA<SpeechHeard>(),
      );
    });
  });
}
