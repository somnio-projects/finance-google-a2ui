import 'package:bloc_test/bloc_test.dart';
import 'package:finance_app/features/conversation/bloc/voice_input_bloc.dart';
import 'package:finance_app/speech/speech_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_speech_recognizer.dart';

/// Lets the bloc's `await for` subscribe before the test speaks into it.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('VoiceInputBloc', () {
    late FakeSpeechRecognizer open;

    setUp(() => open = FakeSpeechRecognizer.live());

    test('reads the engine before the first frame (AC-1)', () {
      expect(
        VoiceInputBloc(recognizer: FakeSpeechRecognizer.absent()).state.status,
        VoiceInputStatus.unavailable,
      );
      expect(
        VoiceInputBloc(recognizer: open).state.status,
        VoiceInputStatus.idle,
      );
    });

    blocTest<VoiceInputBloc, VoiceInputState>(
      'shows the partial, then the final, then goes idle (AC-2, AC-3)',
      build: () => VoiceInputBloc(
        recognizer: FakeSpeechRecognizer.scripted(const <SpeechEvent>[
          SpeechHeard('how did', isFinal: false),
          SpeechHeard('how did my portfolio do', isFinal: true),
        ]),
      ),
      act: (bloc) => bloc.add(VoiceInputStarted()),
      expect: () => const <VoiceInputState>[
        VoiceInputState(status: VoiceInputStatus.listening),
        VoiceInputState(
          status: VoiceInputStatus.listening,
          transcript: 'how did',
        ),
        VoiceInputState(
          status: VoiceInputStatus.listening,
          transcript: 'how did my portfolio do',
        ),
        // The session ended by itself; the words stay in the field (AC-4).
        VoiceInputState(transcript: 'how did my portfolio do'),
      ],
    );

    blocTest<VoiceInputBloc, VoiceInputState>(
      'keeps what was heard when the person stops it (AC-5)',
      build: () => VoiceInputBloc(recognizer: open),
      act: (bloc) async {
        bloc.add(VoiceInputStarted());
        await settle();
        open.say(const SpeechHeard('sell ten shares', isFinal: false));
        await settle();
        bloc.add(VoiceInputStopped());
        await settle();
      },
      expect: () => const <VoiceInputState>[
        VoiceInputState(status: VoiceInputStatus.listening),
        VoiceInputState(
          status: VoiceInputStatus.listening,
          transcript: 'sell ten shares',
        ),
        VoiceInputState(transcript: 'sell ten shares'),
      ],
      verify: (_) => expect(open.stops, 1),
    );

    blocTest<VoiceInputBloc, VoiceInputState>(
      'ignores a second tap while the microphone is already open',
      build: () => VoiceInputBloc(recognizer: open),
      act: (bloc) async {
        bloc.add(VoiceInputStarted());
        await settle();
        bloc.add(VoiceInputStarted());
        await settle();
        await open.finish();
      },
      expect: () => const <VoiceInputState>[
        VoiceInputState(status: VoiceInputStatus.listening),
        VoiceInputState(),
      ],
      // One session, not two: a second `start()` on a live engine throws in
      // the browser, and there would be nothing to report if it did not.
      verify: (_) => expect(open.starts, 1),
    );
  });
}
