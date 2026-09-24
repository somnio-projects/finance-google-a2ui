import 'package:finance_app/skeleton/skeleton_rows.dart';
import 'package:finance_app/skeleton/skeleton_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  group(SkeletonRows, () {
    testWidgets('stacks one block per row, at the row height', (tester) async {
      await tester.pumpApp(
        const SkeletonRows(count: 4, height: 60),
        reducedMotion: true,
      );
      await tester.pumpAndSettle();
      final blocks = tester.widgetList<SkeletonShimmer>(
        find.byType(SkeletonShimmer),
      );
      expect(blocks, hasLength(4));
      expect(blocks.every((b) => b.height == 60), isTrue);
      expect(blocks.every((b) => b.radius == 14), isTrue);
    });

    testWidgets('leaves the gap between rows and none after the last', (
      tester,
    ) async {
      await tester.pumpApp(
        const Center(
          child: SkeletonRows(count: 3, height: 20, gap: 12, radius: 6),
        ),
        reducedMotion: true,
      );
      await tester.pumpAndSettle();
      final blocks = find.byType(SkeletonShimmer);
      final tops = <double>[
        for (var index = 0; index < 3; index++)
          tester.getTopLeft(blocks.at(index)).dy,
      ];
      // 20 high, 12 apart: the blocks start 32 apart, and the column is
      // 3 × 20 + 2 × 12 = 84 tall, so nothing trails the last one.
      expect(tops[1] - tops[0], equals(32));
      expect(tops[2] - tops[1], equals(32));
      expect(tester.getSize(find.byType(SkeletonRows)).height, equals(84));
      expect(
        tester.widget<SkeletonShimmer>(blocks.first),
        isA<SkeletonShimmer>().having((b) => b.radius, 'radius', 6),
      );
    });

    testWidgets('a count of nothing draws nothing', (tester) async {
      await tester.pumpApp(
        const SkeletonRows(count: 0, height: 20),
        reducedMotion: true,
      );
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonShimmer), findsNothing);
    });
  });
}
