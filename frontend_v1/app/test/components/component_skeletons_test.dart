import 'dart:ui' show PictureRecorder;

import 'package:finance_app/components/holdings_allocation/holdings_allocation_component.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_skeleton.dart';
import 'package:finance_app/components/payoff_chart/payoff_chart_component.dart';
import 'package:finance_app/components/payoff_chart/payoff_chart_skeleton.dart';
import 'package:finance_app/components/payoff_chart/payoff_chart_skeleton_painter.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_component.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_skeleton.dart';
import 'package:finance_app/components/view_component.dart';
import 'package:finance_app/skeleton/skeleton_pulse.dart';
import 'package:finance_app/skeleton/skeleton_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

/// Pumps [component]'s skeleton in a 390-wide column, as the Assistant does.
Future<void> pumpSkeleton(
  WidgetTester tester,
  ViewComponent component, {
  Brightness brightness = Brightness.light,
}) => tester.pumpApp(
  Scaffold(
    body: SizedBox(width: 390, child: Builder(builder: component.skeleton)),
  ),
  brightness: brightness,
  surfaceSize: const Size(390, 900),
);

void main() {
  group(HoldingsAllocationSkeleton, () {
    testWidgets("a ring with the card's hole, six bars and the tool's name", (
      tester,
    ) async {
      await pumpSkeleton(tester, const HoldingsAllocationComponent());
      expect(find.byType(HoldingsAllocationSkeleton), findsOneWidget);
      // The ring, the title bar, the caption bar and four legend bars.
      expect(find.byType(SkeletonShimmer), findsNWidgets(7));
      expect(find.text(HoldingsAllocationSkeleton.caption), findsOneWidget);
      final ring = tester.widget<SkeletonShimmer>(
        find.byType(SkeletonShimmer).first,
      );
      expect(ring.shape, BoxShape.circle);
      expect(ring.width, HoldingsAllocationSkeleton.ringDiameter);
      expect(
        tester.getSize(
          find
              .descendant(
                of: find.byType(SkeletonShimmer).first,
                matching: find.byType(Container),
              )
              .last,
        ),
        const Size.square(HoldingsAllocationSkeleton.holeDiameter),
      );
    });

    testWidgets('draws under the dark theme too', (tester) async {
      await pumpSkeleton(
        tester,
        const HoldingsAllocationComponent(),
        brightness: Brightness.dark,
      );
      expect(find.byType(HoldingsAllocationSkeleton), findsOneWidget);
    });
  });

  group(ScenarioComparisonSkeleton, () {
    testWidgets("a header row and four metric rows in the table's grid", (
      tester,
    ) async {
      await pumpSkeleton(tester, const ScenarioComparisonComponent());
      expect(find.byType(ScenarioComparisonSkeleton), findsOneWidget);
      // Five rows × (one label + three cells).
      expect(find.byType(SkeletonShimmer), findsNWidgets(20));
      final header = tester.widget<SkeletonShimmer>(
        find.byType(SkeletonShimmer).first,
      );
      expect(header.width, ScenarioComparisonSkeleton.headerLabelWidth);
      expect(header.height, 14);
    });
  });

  group(PayoffChartSkeleton, () {
    testWidgets("a breathing plot with the tool's name in a pill", (
      tester,
    ) async {
      await pumpSkeleton(tester, const PayoffChartComponent());
      expect(find.byType(PayoffChartSkeleton), findsOneWidget);
      expect(find.text(PayoffChartSkeleton.caption), findsOneWidget);
      // The plot and the legend bars each breathe.
      expect(find.byType(SkeletonPulse), findsNWidgets(2));
      final paint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is PayoffSkeletonPainter,
        ),
      );
      expect(paint.painter, isA<PayoffSkeletonPainter>());
      final plot = tester.getSize(find.byType(AspectRatio));
      expect(
        plot.width / plot.height,
        closeTo(
          PayoffChartSkeleton.designWidth / PayoffChartSkeleton.designHeight,
          0.01,
        ),
      );
    });

    test('the painter repaints only when its colour changes', () {
      const a = PayoffSkeletonPainter(color: Color(0xFFE6E2EF));
      const b = PayoffSkeletonPainter(color: Color(0xFF22232B));
      expect(a.shouldRepaint(b), isTrue);
      expect(
        a.shouldRepaint(const PayoffSkeletonPainter(color: Color(0xFFE6E2EF))),
        isFalse,
      );
    });

    test('the painter draws its dashes on any canvas size', () {
      // Painted, not asserted pixel by pixel: the point is that the dashed
      // path walks to the end of the line without throwing on a scaled box.
      final recorder = PictureRecorder();
      const PayoffSkeletonPainter(color: Color(0xFFE6E2EF))
          .paint(Canvas(recorder), const Size(250, 140));
      expect(recorder.endRecording(), isNotNull);
    });
  });
}
