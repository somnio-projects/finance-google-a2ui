import 'package:finance_app/features/home/view/home_questions_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group(HomeQuestionsRail, () {
    const questions = <String>[
      'What moved my portfolio today?',
      'Tax impact of selling BTC?',
      r'Build a $10k order in tech',
    ];

    testWidgets(
      'shows the arrow while chips are off-screen, and scrolls on tap',
      (tester) async {
        await tester.pumpApp(
          const SizedBox(
            width: 390,
            child: HomeQuestionsRail(questions: questions),
          ),
        );
        await tester.pump();
        expect(find.byKey(HomeQuestionsRail.arrowKey), findsOneWidget);
        final before = tester
            .getTopLeft(find.text('💬 Tax impact of selling BTC?'))
            .dx;
        await tester.tap(find.byKey(HomeQuestionsRail.arrowKey));
        await tester.pumpAndSettle();
        final after = tester
            .getTopLeft(find.text('💬 Tax impact of selling BTC?'))
            .dx;
        expect(after, lessThan(before));
        // Keep advancing; at the end nothing is off-screen and the arrow
        // goes away. Bounded, so a rail that never ends is a failure, not a
        // hang.
        for (var taps = 0; taps < 6; taps++) {
          if (find.byKey(HomeQuestionsRail.arrowKey).evaluate().isEmpty) break;
          await tester.tap(find.byKey(HomeQuestionsRail.arrowKey));
          await tester.pumpAndSettle();
        }
        expect(find.byKey(HomeQuestionsRail.arrowKey), findsNothing);
        // …and the way back appears on the left (spec frontend/0012).
        expect(find.byKey(HomeQuestionsRail.backKey), findsOneWidget);
        for (var taps = 0; taps < 6; taps++) {
          if (find.byKey(HomeQuestionsRail.backKey).evaluate().isEmpty) break;
          await tester.tap(find.byKey(HomeQuestionsRail.backKey));
          await tester.pumpAndSettle();
        }
        expect(find.byKey(HomeQuestionsRail.backKey), findsNothing);
        expect(find.byKey(HomeQuestionsRail.arrowKey), findsOneWidget);
      },
    );

    testWidgets('a wide screen fits everything and shows no arrow', (
      tester,
    ) async {
      await tester.pumpApp(
        const SizedBox(
          width: 1200,
          child: HomeQuestionsRail(questions: questions),
        ),
        surfaceSize: const Size(1400, 600),
      );
      await tester.pump();
      expect(find.byKey(HomeQuestionsRail.arrowKey), findsNothing);
      expect(find.byKey(HomeQuestionsRail.backKey), findsNothing);
    });
  });
}
