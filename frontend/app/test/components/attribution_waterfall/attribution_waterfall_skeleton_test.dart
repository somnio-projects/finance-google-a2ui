import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_component.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_skeleton.dart';
import 'package:finance_app/skeleton/skeleton_pulse.dart';
import 'package:finance_app/skeleton/surface_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// The loading state (spec frontend/0028 AC-6): the card's own shape, no
/// words, no figures, and motion that the platform can switch off.
void main() {
  group(AttributionWaterfallSkeleton, () {
    testWidgets('is what the component draws while its payload is away', (
      tester,
    ) async {
      // The seam is the override, not a registry entry: before this the card
      // fell back to the Assistant's generic surface, which is the same
      // placeholder every component showed (0015 OD-3).
      await tester.pumpApp(
        Builder(
          builder: (context) =>
              const AttributionWaterfallComponent().skeleton(context),
        ),
        reducedMotion: true,
      );
      expect(find.byType(AttributionWaterfallSkeleton), findsOneWidget);
      expect(find.byType(SurfaceSkeleton), findsNothing);
    });

    testWidgets('draws no text at all', (tester) async {
      // N-3: a placeholder that looked like a figure would be a figure the
      // client made up. Not even a caption — this card has no tool name to
      // print the way the payoff card does.
      await tester.pumpApp(
        const SizedBox(width: 380, child: AttributionWaterfallSkeleton()),
        reducedMotion: true,
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('draws one column per step, at uneven heights', (tester) async {
      await tester.pumpApp(
        const SizedBox(width: 380, child: AttributionWaterfallSkeleton()),
        reducedMotion: true,
      );
      const heights = AttributionWaterfallSkeleton.columnHeights;
      expect(heights, hasLength(7));
      // Uneven on purpose: seven equal bars read as a chart that has already
      // loaded, which is the opposite of what a skeleton is for.
      expect(heights.toSet(), hasLength(heights.length));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxWidth ==
                  AttributionWaterfallSkeleton.columnWidth,
        ),
        findsNWidgets(heights.length),
      );
    });

    testWidgets('borrows the 0015 motion rather than declaring its own', (
      tester,
    ) async {
      // ADR-L: a skeleton composes the primitives, so reduced motion is
      // inherited. An `AnimationController` here would be an animation
      // nobody can turn off.
      await tester.pumpApp(
        const SizedBox(width: 380, child: AttributionWaterfallSkeleton()),
        reducedMotion: true,
      );
      expect(find.byType(SkeletonPulse), findsOneWidget);
    });

    testWidgets('renders in dark without overflowing', (tester) async {
      await tester.pumpApp(
        const SizedBox(width: 380, child: AttributionWaterfallSkeleton()),
        brightness: Brightness.dark,
        reducedMotion: true,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
