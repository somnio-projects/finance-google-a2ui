import 'package:finance_app/components/taxlots_table/taxlot_chip.dart';
import 'package:finance_app/components/taxlots_table/taxlot_column_headers.dart';
import 'package:finance_app/components/taxlots_table/taxlot_row_tile.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_card.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_component.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_empty.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_footer.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';
import 'taxlots_table_harness.dart';

void main() {
  group(TaxLotsTableCard, () {
    const component = TaxLotsTableComponent();
    late Map<String, dynamic> example;

    setUp(() {
      example = CatalogSnapshot.load().exampleFor('TaxLotTable');
    });

    Future<void> pumpCard(
      WidgetTester tester,
      TaxLotsTableData data, {
      Brightness brightness = Brightness.light,
    }) => tester.pumpApp(
      Scaffold(
        body: Center(
          // The design's card width for a single column at 1024.
          child: SizedBox(width: 533.37, child: TaxLotsTableCard(data: data)),
        ),
      ),
      brightness: brightness,
    );

    testWidgets('shows every display string the payload carries', (
      tester,
    ) async {
      await pumpCard(tester, component.read(ViewPayload.fromJson(example)));
      expect(find.text('Tax lots this sale consumes'), findsOneWidget);
      expect(find.text('Sell 75 NVDA under FIFO'), findsOneWidget);
      expect(find.text(r'$45,600.00'), findsOneWidget);
      expect(find.text(r'$72,279.60'), findsOneWidget);
      expect(find.text(r'+$26,679.60'), findsOneWidget);
      expect(find.text(r'$14,400.00'), findsOneWidget);
      expect(find.text(r'+$3,669.90'), findsOneWidget);
      expect(find.text('Realised P/L'), findsOneWidget);
      expect(find.text(r'+$30,349.50'), findsOneWidget);
      expect(find.text('2025-01-13'), findsOneWidget);
    });

    testWidgets('never puts a raw figure on screen', (tester) async {
      // The N-4 half of the contract. `units`, and every raw `amount`
      // beside a display string, must not reach a `Text`.
      await pumpCard(tester, component.read(ViewPayload.fromJson(example)));
      for (final raw in <String>[
        '60.0000',
        '15.0000',
        '45600.00',
        '26679.600000',
        '30349.500000',
        '72279.600000',
      ]) {
        expect(find.text(raw), findsNothing, reason: '$raw is a raw figure');
      }
    });

    testWidgets('draws the column headers over the rows', (tester) async {
      await pumpCard(tester, component.read(ViewPayload.fromJson(example)));
      expect(find.byType(TaxLotColumnHeaders), findsOneWidget);
      // Two captions are the payload's own labels, so they follow the
      // view's `locale` option; three are client-authored because the
      // contract supplies none for those columns.
      expect(find.text('Cost basis'), findsOneWidget);
      expect(find.text('Proceeds'), findsOneWidget);
      for (final caption in <String>[
        TaxLotColumnHeaders.acquired,
        TaxLotColumnHeaders.gainLoss,
        TaxLotColumnHeaders.term,
      ]) {
        expect(find.text(caption), findsOneWidget);
      }
      expect(find.byType(TaxLotRowTile), findsNWidgets(2));
      expect(find.byType(TaxLotsTableFooter), findsOneWidget);
    });

    testWidgets('keys the two terms beside the title', (tester) async {
      await pumpCard(tester, component.read(ViewPayload.fromJson(example)));
      // Two legend pills, plus one term pill per row, plus two split pills
      // in the footer.
      expect(find.byType(TaxLotChip), findsNWidgets(2 + 2 + 2));
      expect(find.text('Short-term'), findsNWidgets(2));
      expect(find.text('Long-term'), findsNWidgets(2));
    });

    testWidgets('shows the empty state and still shows the footer', (
      tester,
    ) async {
      await pumpCard(
        tester,
        component.read(ViewPayload.fromJson(withoutLots(example))),
      );
      expect(find.byType(TaxLotsTableEmpty), findsOneWidget);
      expect(find.text(TaxLotsTableEmpty.message), findsOneWidget);
      expect(find.byType(TaxLotRowTile), findsNothing);
      expect(find.byType(TaxLotColumnHeaders), findsNothing);
      // The realised result is still the answer to the question asked.
      expect(find.text(r'+$30,349.50'), findsOneWidget);
    });

    testWidgets('renders in the dark theme', (tester) async {
      await pumpCard(
        tester,
        component.read(ViewPayload.fromJson(example)),
        brightness: Brightness.dark,
      );
      expect(find.byType(TaxLotRowTile), findsNWidgets(2));
    });
  });
}
