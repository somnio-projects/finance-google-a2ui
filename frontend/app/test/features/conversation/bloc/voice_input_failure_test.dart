import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/conversation/bloc/voice_input_bloc.dart';
import 'package:finance_app/speech/speech_failure.dart';
import 'package:finance_app/speech/speech_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_speech_recognizer.dart';

void main() {
  group('VoiceInputBloc — every way a session fails (AC-6)', () {
    // Quantified over the enum rather than over a list somebody maintains: a
    // new failure kind is a new test here the moment it is declared.
    for (final failure in SpeechFailure.values) {
      blocTest<VoiceInputBloc, VoiceInputState>(
        'states ${failure.name} and returns the button to idle',
        build: () => VoiceInputBloc(
          recognizer: FakeSpeechRecognizer.scripted(<SpeechEvent>[
            SpeechFailed(failure),
          ]),
        ),
        act: (bloc) => bloc.add(VoiceInputStarted()),
        expect: () => <VoiceInputState>[
          const VoiceInputState(status: VoiceInputStatus.listening),
          // Idle, not listening: the mic is ready for the next tap, and the
          // notice counter advanced so the sentence is actually shown.
          VoiceInputState(failure: failure, notices: 1),
        ],
      );
    }

    blocTest<VoiceInputBloc, VoiceInputState>(
      'answers every tap on a mic that cannot listen (AC-1, AC-7)',
      // Two equal failures must still be two states, or the second tap is
      // silent — spec frontend/0021 OD-2, one layer in.
      build: () => VoiceInputBloc(recognizer: FakeSpeechRecognizer.absent()),
      act: (bloc) => bloc
        ..add(VoiceInputStarted())
        ..add(VoiceInputStarted()),
      expect: () => const <VoiceInputState>[
        VoiceInputState(
          status: VoiceInputStatus.unavailable,
          failure: SpeechFailure.unavailable,
          notices: 1,
        ),
        VoiceInputState(
          status: VoiceInputStatus.unavailable,
          failure: SpeechFailure.unavailable,
          notices: 2,
        ),
      ],
    );

    test('two taps are two events, not one value seen twice', () {
      // Deliberately NOT value-equal (see `voice_input_event.dart`): a mic
      // tapped twice has happened twice, and the second one has a notice of
      // its own.
      expect(VoiceInputStarted(), isNot(VoiceInputStarted()));
      expect(VoiceInputStarted(), isNot(isA<VoiceInputStopped>()));
    });
  });
}
