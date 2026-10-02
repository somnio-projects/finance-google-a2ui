import 'package:finance_app/skeleton/skeleton_shimmer.dart';
import 'package:finance_app/theme/skeleton_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'skeleton_motion_harness.dart';

void main() {
  group(SkeletonShimmer, () {
    final container = find.descendant(
      of: find.byType(SkeletonShimmer),
      matching: find.byType(Container),
    );

    testWidgets('sweeps the highlight band across the block', (tester) async {
      await pumpMotion(tester, const SkeletonShimmer(width: 120, height: 18));
      final before = gradientOf(tester, container).begin as Alignment;
      await tester.pump(const Duration(milliseconds: 350));
      final after = gradientOf(tester, container).begin as Alignment;
      // A quarter period later the band has moved a quarter of its travel.
      expect(after.x, greaterThan(before.x));
      expect(after.x - before.x, closeTo(1, 0.05));
      final colors = gradientOf(tester, container).colors;
      expect(colors.first, skeletonTokensLight.shimmerBase);
      expect(colors[1], skeletonTokensLight.shimmerHighlight);
    });

    testWidgets('takes the size and the radius it is given', (tester) async {
      await pumpMotion(
        tester,
        const SkeletonShimmer(width: 150, height: 18, radius: 6),
      );
      expect(tester.getSize(find.byType(SkeletonShimmer)), const Size(150, 18));
      final decoration =
          tester.widget<Container>(container).decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(6));
    });

    testWidgets('a circle has no corner radius and keeps its child', (
      tester,
    ) async {
      await pumpMotion(
        tester,
        const SkeletonShimmer(
          width: 112,
          height: 112,
          shape: BoxShape.circle,
          child: Text('hole'),
        ),
      );
      final decoration =
          tester.widget<Container>(container).decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.borderRadius, isNull);
      expect(find.text('hole'), findsOneWidget);
    });

    testWidgets('holds still mid-sweep under reduced motion', (tester) async {
      await pumpMotion(
        tester,
        const SkeletonShimmer(width: 120, height: 18),
        reducedMotion: true,
      );
      final before = gradientOf(tester, container).begin as Alignment;
      await tester.pump(const Duration(milliseconds: 700));
      final after = gradientOf(tester, container).begin as Alignment;
      expect(after, before);
      // Centred: the band is visible, the block reads as a placeholder.
      expect(before.x, -1);
    });

    testWidgets('uses the dark palette under the dark theme', (tester) async {
      await pumpMotion(
        tester,
        const SkeletonShimmer(width: 120, height: 18),
        brightness: Brightness.dark,
      );
      expect(
        gradientOf(tester, container).colors.first,
        skeletonTokensDark.shimmerBase,
      );
    });
  });
}
