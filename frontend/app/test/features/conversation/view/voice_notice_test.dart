import 'package:finance_app/features/conversation/view/voice_notice.dart';
import 'package:finance_app/speech/speech_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('voiceNotice (spec frontend/0022 OD-5)', () {
    test('every failure kind has its own sentence', () {
      // Quantified over the enum: a kind added without a sentence does not
      // compile, and a kind added with somebody else's sentence fails here.
      final sentences = SpeechFailure.values.map(voiceNotice).toList();
      expect(sentences.toSet(), hasLength(SpeechFailure.values.length));
      for (final sentence in sentences) {
        expect(sentence, isNotEmpty);
        expect(sentence, endsWith('.'));
      }
    });

    test(
      'names the browsers that can, rather than only the one that cannot',
      () {
        expect(voiceNotice(SpeechFailure.unavailable), contains('Chrome'));
        expect(
          voiceNotice(SpeechFailure.unavailable),
          contains('Type your question'),
        );
      },
    );

    test('tells a blocked microphone where to unblock it', () {
      expect(
        voiceNotice(SpeechFailure.permissionDenied),
        contains('Allow it in your browser'),
      );
    });

    test('does not blame the person for saying nothing', () {
      expect(voiceNotice(SpeechFailure.noSpeech), contains('Tap the mic'));
    });
  });
}
