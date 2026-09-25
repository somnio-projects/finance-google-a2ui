import 'package:finance_app/components/taxlots_table/taxlots_table_card.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_component.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_data.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_skeleton.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';
import 'taxlots_table_harness.dart';

/// Goldens for the two layouts, both themes and the loading state (AC-8).
///
/// They go through the tolerant comparator in `flutter_test_config.dart`
/// (ADR-L D-15) — a raster is not portable, and the measured cross-platform
/// noise floor is 0.69 % against a 1.5 % threshold. **Text renders in
/// Flutter's test font**, a block per glyph, so what these prove is the
/// chrome the row tests cannot see: the rail, the tint, the tick, the rule,
/// the pills and the way the six columns fall. Colour and geometry are
/// asserted directly beside them, which is what makes a tolerance here safe
/// rather than a loosened threshold.
void main() {
  group('TaxLotTable goldens', () {
    const component = TaxLotsTableComponent();
    const boundary = Key('golden-subject');
    late TaxLotsTableData data;

    setUp(() {
      data = component.read(
        ViewPayload.fromJson(CatalogSnapshot.load().exampleFor('TaxLotTable')),
      );
    });

    Future<void> shoot(
      WidgetTester tester,
      Widget subject,
      double width,
      String name, {
      Brightness brightness = Brightness.light,
    }) async {
      await tester.pumpApp(
        Center(
          child: RepaintBoundary(
            key: boundary,
            child: SizedBox(width: width, child: subject),
          ),
        ),
        brightness: brightness,
        surfaceSize: const Size(900, 900),
        // A shimmer repeats for ever, so a skeleton golden never settles
        // without this; it is also the state the card must be correct in.
        reducedMotion: true,
      );
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('goldens/$name.png'),
      );
    }

    testWidgets('the table, light', (tester) async {
      await shoot(tester, TaxLotsTableCard(data: data), 600, 'taxlot_table');
    });

    testWidgets('the table, dark', (tester) async {
      await shoot(
        tester,
        TaxLotsTableCard(data: data),
        600,
        'taxlot_table_dark',
        brightness: Brightness.dark,
      );
    });

    testWidgets('the phone card, light', (tester) async {
      await shoot(tester, TaxLotsTableCard(data: data), 328, 'taxlot_phone');
    });

    testWidgets('the phone card, dark', (tester) async {
      await shoot(
        tester,
        TaxLotsTableCard(data: data),
        328,
        'taxlot_phone_dark',
        brightness: Brightness.dark,
      );
    });

    testWidgets('a table whose lots the sale all consumes', (tester) async {
      // The kit's *selected* artboard, which is a payload rather than an
      // interaction (OD-3): the tint, the filled boxes and the ticks.
      final consumed = cardData(lots: <TaxLot>[lot(fullySold: true), lot()]);
      await shoot(
        tester,
        TaxLotsTableCard(data: consumed),
        600,
        'taxlot_table_consumed',
      );
    });

    testWidgets('the loading state, light', (tester) async {
      await shoot(tester, const TaxLotsTableSkeleton(), 600, 'taxlot_skeleton');
    });
  });
}
