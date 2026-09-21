import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_card.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_component.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';

/// Goldens for the three states the design's catalog page specifies.
///
/// They sit **beside** the geometry assertions in `finance_charts`, not
/// instead of them: a golden tells you something moved, and the arithmetic
/// tells you what. Both go red together when a scale's domain changes, which
/// is the mutation check recorded in the GGU-55 PR body.
void main() {
  group('AttributionWaterfall goldens', () {
    late AttributionWaterfallData data;

    setUp(() {
      data = const AttributionWaterfallComponent().read(
        ViewPayload.fromJson(
          CatalogSnapshot.load().exampleFor('AttributionWaterfall'),
        ),
      );
    });

    Widget subject({String? selected}) => Center(
      child: SizedBox(
        // The design's artboard width for a single card at 1024.
        width: 571.4,
        child: AttributionWaterfallCard(
          data: data,
          initialSelectedKey: selected,
        ),
      ),
    );

    testWidgets('default, light', (tester) async {
      await tester.pumpApp(subject());
      await expectLater(
        find.byType(AttributionWaterfallCard),
        matchesGoldenFile('goldens/attribution_waterfall_light.png'),
      );
    });

    testWidgets('default, dark', (tester) async {
      await tester.pumpApp(subject(), brightness: Brightness.dark);
      await expectLater(
        find.byType(AttributionWaterfallCard),
        matchesGoldenFile('goldens/attribution_waterfall_dark.png'),
      );
    });

    testWidgets('selected, light', (tester) async {
      await tester.pumpApp(subject(selected: 'BTC'));
      await expectLater(
        find.byType(AttributionWaterfallCard),
        matchesGoldenFile('goldens/attribution_waterfall_selected.png'),
      );
    });
  });
}
