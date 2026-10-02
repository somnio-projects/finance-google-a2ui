import 'package:finance_app/features/conversation/view/voice_notice.dart';
import 'package:finance_app/speech/speech_failure.dart';
import 'package:finance_app/speech/speech_recognizer.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_speech_recognizer.dart';
import 'conversation_harness.dart';

void main() {
  group('the composer dictates (spec frontend/0023)', () {
    late MockAgentRepository agent;
    late MockViewsRepository views;
    late FakeSpeechRecognizer engine;

    setUp(() {
      agent = MockAgentRepository();
      views = MockViewsRepository();
      engine = FakeSpeechRecognizer.live();
      scriptTurn(agent, const <AgentEvent>[]);
    });

    testWidgets('fills the field and sends nothing on its own (AC-2..AC-5)', (
      tester,
    ) async {
      await pumpConversation(
        tester,
        agent: agent,
        views: views,
        speech: engine,
      );
      expect(find.byTooltip(voiceIdleTooltip), findsOneWidget);

      await tester.tap(find.byTooltip(voiceIdleTooltip));
      await tester.pump();
      // The control announces that it is now the way to stop (AC-2).
      expect(find.byTooltip(voiceListeningTooltip), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

      engine.say(const SpeechHeard('how did my', isFinal: false));
      await tester.pump();
      expect(find.text('how did my'), findsOneWidget);

      engine.say(const SpeechHeard('how did my portfolio do', isFinal: true));
      await tester.pump();
      await tester.tap(find.byTooltip(voiceListeningTooltip));
      await tester.pumpAndSettle();

      // AC-4 and AC-5: the words are in the field, the button is a mic
      // again, and the agent has not been asked anything.
      expect(find.text('how did my portfolio do'), findsOneWidget);
      expect(find.byTooltip(voiceIdleTooltip), findsOneWidget);
      verifyNever(
        () => agent.startTurn(
          text: any(named: 'text'),
          messages: any(named: 'messages'),
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      );

      // AC-8: it reaches the agent through the one path that already exists.
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      verify(
        () => agent.startTurn(
          text: 'how did my portfolio do',
          messages: any(named: 'messages'),
          messageId: any(named: 'messageId'),
          contextId: any(named: 'contextId'),
        ),
      ).called(1);
    });

    testWidgets('says why on a build with no engine, every time (AC-1, AC-7)', (
      tester,
    ) async {
      // No `speech:`, so the tree gets what the VM really has — nothing.
      await pumpConversation(tester, agent: agent, views: views);
      expect(find.byTooltip(voiceUnavailableTooltip), findsOneWidget);

      await tester.tap(find.byTooltip(voiceUnavailableTooltip));
      await tester.pump();
      expect(find.text(voiceNotice(SpeechFailure.unavailable)), findsOneWidget);

      // The snackbar times out, and the SECOND tap must speak too: keying the
      // listener on the failure value instead of the counter is exactly how
      // this control would go quiet again (spec 0021 OD-2).
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text(voiceNotice(SpeechFailure.unavailable)), findsNothing);
      await tester.tap(find.byTooltip(voiceUnavailableTooltip));
      await tester.pump();
      expect(find.text(voiceNotice(SpeechFailure.unavailable)), findsOneWidget);
    });

    testWidgets('states a refusal in the backend-free words it owns (AC-6)', (
      tester,
    ) async {
      await pumpConversation(
        tester,
        agent: agent,
        views: views,
        speech: engine,
      );
      await tester.tap(find.byTooltip(voiceIdleTooltip));
      await tester.pump();
      engine.say(const SpeechFailed(SpeechFailure.permissionDenied));
      await tester.pump();
      expect(
        find.text(voiceNotice(SpeechFailure.permissionDenied)),
        findsOneWidget,
      );
      // And the mic is ready again rather than stuck looking live.
      expect(find.byTooltip(voiceIdleTooltip), findsOneWidget);
    });
  });
}
