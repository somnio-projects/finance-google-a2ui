import 'package:finance_app/charts/donut_chart.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_component.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_model.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';

/// Goldens for the ring, in both themes and in the selected state.
///
/// They sit **beside** the geometry assertions in `finance_charts`, not
/// instead of them: a golden says something moved, the arithmetic says what.
/// The geometry suite compares the arcs against the design's own rendered
/// `conic-gradient` stops to 0.01°; these prove the colours came from the
/// right ramp and the ring is a ring.
///
/// **They capture the ring, not the whole card**, for the reason ADR-L D-15
/// records and the waterfall goldens measured: glyph edges are where nearly
/// all cross-platform raster noise lives, and a whole-card golden here would
/// carry a header, five labels and ten figures. The card's text is asserted
/// by `find.text` in `holdings_allocation_card_test.dart`, which is a better
/// check for text than a raster, and its chrome by its constants.
void main() {
  group('AllocationSummary goldens', () {
    late AllocationData data;

    setUp(() {
      data = const HoldingsAllocationComponent().read(
        ViewPayload.fromJson(
          CatalogSnapshot.load().exampleFor('AllocationSummary'),
        ),
      );
    });

    /// The ring inside its own repaint boundary.
    ///
    /// Without the boundary `matchesGoldenFile` walks up to the nearest one —
    /// the whole test surface — and silently captures more than the finder
    /// names.
    const boundary = Key('golden-subject');

    Widget subject({int? selected}) => Center(
      child: RepaintBoundary(
        key: boundary,
        child: DonutChart(weights: data.weights, selectedIndex: selected),
      ),
    );

    testWidgets('default, light', (tester) async {
      await tester.pumpApp(subject());
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/holdings_allocation_light.png'),
      );
    });

    testWidgets('default, dark', (tester) async {
      await tester.pumpApp(subject(), brightness: Brightness.dark);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/holdings_allocation_dark.png'),
      );
    });

    testWidgets('selected, light', (tester) async {
      await tester.pumpApp(subject(selected: 1));
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/holdings_allocation_selected.png'),
      );
    });
  });
}
