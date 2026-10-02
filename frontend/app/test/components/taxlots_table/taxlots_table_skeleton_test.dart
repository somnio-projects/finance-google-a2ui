import 'package:finance_app/components/taxlots_table/taxlots_table_component.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_skeleton.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_surface.dart';
import 'package:finance_app/skeleton/skeleton_shimmer.dart';
import 'package:finance_app/skeleton/surface_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// The kit's `Loading` artboard (AC-6).
///
/// `reducedMotion: true` on every pump, for the reason the harness records:
/// a shimmer repeats for ever, so `pumpAndSettle` never returns while one is
/// animating. It is also the state this card must be correct in — an
/// animation nobody can turn off is an accessibility defect (0020 OD-7).
void main() {
  group(TaxLotsTableSkeleton, () {
    Future<void> pumpSkeleton(
      WidgetTester tester, {
      Brightness brightness = Brightness.light,
    }) => tester.pumpApp(
      const Scaffold(
        body: Center(
          child: SizedBox(width: 600, child: TaxLotsTableSkeleton()),
        ),
      ),
      brightness: brightness,
      reducedMotion: true,
    );

    testWidgets('draws the card own shape, not the generic surface', (
      tester,
    ) async {
      await pumpSkeleton(tester);
      expect(find.byType(TaxLotsTableSurface), findsOneWidget);
      expect(find.byType(SurfaceSkeleton), findsNothing);
    });

    testWidgets('draws a bar for every line the table will have', (
      tester,
    ) async {
      await pumpSkeleton(tester);
      // Title, two legend pills, the caption line, four rows, the footer.
      expect(
        find.byType(SkeletonShimmer),
        findsNWidgets(1 + 2 + 1 + TaxLotsTableSkeleton.rowCount + 1),
      );
    });

    testWidgets('shows no text at all', (tester) async {
      // Nothing a skeleton draws may look like a figure (N-3): there is no
      // payload yet, so anything readable here would be invented.
      await pumpSkeleton(tester);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders in the dark theme', (tester) async {
      await pumpSkeleton(tester, brightness: Brightness.dark);
      expect(find.byType(SkeletonShimmer), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is what the component offers while its payload is away', (
      tester,
    ) async {
      // The seam, not just the widget: `ViewComponent.skeleton` defaults to
      // the Assistant's generic surface, and this component overrides it
      // because the kit draws its own (spec `frontend/0015` OD-3).
      await tester.pumpApp(
        Builder(
          builder: (context) => const TaxLotsTableComponent().skeleton(context),
        ),
        reducedMotion: true,
      );
      expect(find.byType(TaxLotsTableSkeleton), findsOneWidget);
    });
  });
}
