import 'package:finance_app/skeleton/skeleton_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  group(SkeletonSwitcher, () {
    Widget subject({required bool loading}) => SkeletonSwitcher(
      loading: loading,
      skeleton: const Text('placeholder'),
      child: const Text('payload'),
    );

    testWidgets('shows the skeleton while loading and the child after', (
      tester,
    ) async {
      await tester.pumpApp(subject(loading: true), reducedMotion: true);
      await tester.pumpAndSettle();
      expect(find.text('placeholder'), findsOneWidget);
      expect(find.text('payload'), findsNothing);

      await tester.pumpApp(subject(loading: false), reducedMotion: true);
      await tester.pumpAndSettle();
      expect(find.text('payload'), findsOneWidget);
      expect(find.text('placeholder'), findsNothing);
    });

    testWidgets('cross-fades in $SkeletonSwitcher.period when motion is on', (
      tester,
    ) async {
      await tester.pumpApp(subject(loading: true));
      await tester.pumpApp(subject(loading: false));
      await tester.pump();
      // Mid-fade both are mounted, which is what makes it a fade and not a
      // cut; the outgoing one is gone once the period has elapsed.
      expect(find.text('placeholder'), findsOneWidget);
      expect(find.text('payload'), findsOneWidget);
      await tester.pump(SkeletonSwitcher.period * 2);
      expect(find.text('placeholder'), findsNothing);
      expect(find.text('payload'), findsOneWidget);
    });

    testWidgets('mid-fade it is the height of the incoming child', (
      tester,
    ) async {
      // The default layout builder would hold the page at the *taller* of the
      // two for 180 ms and then shrink — a reflow, which is the thing OD-1
      // exists to prevent. Measured with a 200-high skeleton and a 40-high
      // payload: the swap is 40 from the first frame.
      Widget sized({required bool loading}) => Align(
        alignment: Alignment.topLeft,
        child: SkeletonSwitcher(
          loading: loading,
          skeleton: const SizedBox(width: 100, height: 200),
          child: const SizedBox(width: 100, height: 40),
        ),
      );
      await tester.pumpApp(sized(loading: true));
      expect(tester.getSize(find.byType(SkeletonSwitcher)).height, equals(200));
      await tester.pumpApp(sized(loading: false));
      await tester.pump();
      expect(tester.getSize(find.byType(SkeletonSwitcher)).height, equals(40));
    });

    testWidgets('swaps in Duration.zero under reduced motion', (tester) async {
      // AC-9: the accessible behaviour is an instant, correct swap — not an
      // absent one and not a lingering ghost.
      await tester.pumpApp(subject(loading: true), reducedMotion: true);
      await tester.pumpApp(subject(loading: false), reducedMotion: true);
      await tester.pump();
      expect(find.text('placeholder'), findsNothing);
      expect(find.text('payload'), findsOneWidget);
      expect(
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
        equals(Duration.zero),
      );
    });
  });
}
