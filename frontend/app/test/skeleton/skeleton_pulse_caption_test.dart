import 'package:finance_app/skeleton/skeleton_caption.dart';
import 'package:finance_app/skeleton/skeleton_pulse.dart';
import 'package:finance_app/theme/skeleton_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'skeleton_motion_harness.dart';

void main() {
  group(SkeletonPulse, () {
    // The pulse's own transition — the app shell has fades of its own.
    double opacity(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find.descendant(
            of: find.byType(SkeletonPulse),
            matching: find.byType(FadeTransition),
          ),
        )
        .opacity
        .value;

    testWidgets('breathes between full and the floor', (tester) async {
      await pumpMotion(tester, const SkeletonPulse(child: Text('bar')));
      expect(opacity(tester), 1);
      await tester.pump(SkeletonPulse.period);
      expect(opacity(tester), closeTo(SkeletonPulse.floor, 0.01));
      await tester.pump(SkeletonPulse.period);
      expect(opacity(tester), closeTo(1, 0.01));
      expect(find.text('bar'), findsOneWidget);
    });

    testWidgets('holds at full opacity under reduced motion', (tester) async {
      await pumpMotion(
        tester,
        const SkeletonPulse(child: Text('bar')),
        reducedMotion: true,
      );
      await tester.pump(SkeletonPulse.period);
      expect(opacity(tester), 1);
    });
  });

  group(SkeletonCaption, () {
    double turns(WidgetTester tester) => tester
        .widget<RotationTransition>(
          find.descendant(
            of: find.byType(SkeletonCaption),
            matching: find.byType(RotationTransition),
          ),
        )
        .turns
        .value;

    testWidgets('prints the words beside a turning three-quarter ring', (
      tester,
    ) async {
      await pumpMotion(
        tester,
        const SkeletonCaption(text: 'get_holdings()…', mono: true),
      );
      expect(find.text('get_holdings()…'), findsOneWidget);
      final text = tester.widget<Text>(find.text('get_holdings()…'));
      expect(text.style?.fontFamily, 'Roboto Mono');
      expect(text.style?.fontSize, 10.5);
      expect(text.style?.color, skeletonTokensLight.caption);
      final ring = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(ring.value, 0.75);
      expect(ring.strokeWidth, 1.5);
      expect(
        tester.getSize(find.byType(CircularProgressIndicator)),
        const Size.square(SkeletonCaption.ringSize),
      );
      final before = turns(tester);
      await tester.pump(const Duration(milliseconds: 250));
      expect(turns(tester) - before, closeTo(0.25, 0.01));
    });

    testWidgets('the UI face is the default, and the ring rests when asked', (
      tester,
    ) async {
      await pumpMotion(
        tester,
        const SkeletonCaption(text: 'Loading…'),
        reducedMotion: true,
      );
      final text = tester.widget<Text>(find.text('Loading…'));
      expect(text.style?.fontFamily, isNull);
      expect(text.style?.fontSize, 11.5);
      await tester.pump(const Duration(milliseconds: 250));
      expect(turns(tester), 0);
    });
  });
}
