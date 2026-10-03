import 'package:finance_app/components/taxlots_table/taxlot_chip.dart';
import 'package:finance_app/components/taxlots_table/taxlot_column_headers.dart';
import 'package:finance_app/components/taxlots_table/taxlot_row_tile.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_card.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_component.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_empty.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_footer.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';
import 'taxlot_raw_figures.dart';
import 'taxlots_table_harness.dart';

/// The desktop card, bound to the generated catalog's own example (AC-1,
/// AC-2).
void main() {
  group(TaxLotsTableCard, () {
    const component = TaxLotsTableComponent();
    late Map<String, dynamic> example;

    setUp(() {
      example = CatalogSnapshot.load().exampleFor('TaxLotTable');
    });

    Future<void> pumpCard(
      WidgetTester tester,
      Map<String, dynamic> payload, {
      Brightness brightness = Brightness.light,
    }) => tester.pumpApp(
      Scaffold(
        body: Center(
          // The kit's content column at the desktop artboard's width.
          child: SizedBox(
            width: 600,
            child: TaxLotsTableCard(
              data: component.read(ViewPayload.fromJson(payload)),
            ),
          ),
        ),
      ),
      brightness: brightness,
    );

    testWidgets('shows every display string the payload carries', (
      tester,
    ) async {
      await pumpCard(tester, example);
      expect(find.text('Tax lots this sale consumes'), findsOneWidget);
      expect(find.text('Sell 0.75 BTC under FIFO'), findsOneWidget);
      expect(find.text('01/13/2025'), findsOneWidget);
      expect(find.text('0.25'), findsOneWidget);
      expect(find.text(r'$9,000.00'), findsOneWidget);
      expect(find.text(r'$16,062.50'), findsOneWidget);
      expect(find.text(r'+$7,062.50'), findsWidgets);
      expect(find.text(r'$21,234.00'), findsOneWidget);
      expect(find.text('Realised P/L'), findsOneWidget);
      expect(find.text(r'+$17,953.50'), findsOneWidget);
    });

    testWidgets('never puts a raw figure on screen', (tester) async {
      // The N-4 half of the contract, quantified over **every** path the
      // catalog marks `binding: raw` rather than over a typed list of five
      // — plus `acquired_on`, whose display twin is what the kit shows and
      // which `develop` was printing raw.
      await pumpCard(tester, example);
      final raws = rawFigures(CatalogSnapshot.load().entryFor('TaxLotTable'));
      expect(raws, contains('9000.00'));
      expect(raws, contains('0.25000000'));
      for (final raw in <String>[...raws, '2025-01-13']) {
        expect(find.text(raw), findsNothing, reason: '$raw is a raw figure');
      }
    });

    testWidgets('draws the kit six captions over the rows', (tester) async {
      await pumpCard(tester, example);
      expect(find.byType(TaxLotColumnHeaders), findsOneWidget);
      // Two captions are the payload's own labels, so they follow the view's
      // `locale` option; four are client-authored because the contract
      // supplies none for those columns (OD-1).
      expect(find.text('Quantity'), findsOneWidget);
      expect(find.text('Shares'), findsNothing);
      expect(find.text('Cost basis'), findsOneWidget);
      expect(find.text('Proceeds'), findsOneWidget);
      for (final caption in <String>[
        TaxLotColumnHeaders.acquired,
        TaxLotColumnHeaders.gainLoss,
        TaxLotColumnHeaders.holdingPeriod,
      ]) {
        expect(find.text(caption), findsOneWidget);
      }
      expect(find.byType(TaxLotRowTile), findsNWidgets(2));
      expect(find.byType(TaxLotsTableFooter), findsOneWidget);
    });

    testWidgets('keys the two terms beside the title', (tester) async {
      await pumpCard(tester, example);
      // Two legend pills, plus one term pill per row, plus two split pills
      // in the footer.
      expect(find.byType(TaxLotChip), findsNWidgets(2 + 2 + 2));
      expect(find.text('Short-term'), findsNWidgets(2));
      expect(find.text('Long-term'), findsNWidgets(2));
    });

    testWidgets('nothing on the card is tappable', (tester) async {
      // OD-3: the tick is a state the payload carries, and the view
      // declares no action to send one back.
      await pumpCard(tester, example);
      expect(find.byType(GestureDetector), findsNothing);
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('shows the empty state and still shows the footer', (
      tester,
    ) async {
      await pumpCard(tester, withoutLots(example));
      expect(find.byType(TaxLotsTableEmpty), findsOneWidget);
      expect(find.text(TaxLotsTableEmpty.message), findsOneWidget);
      expect(find.byType(TaxLotRowTile), findsNothing);
      expect(find.byType(TaxLotColumnHeaders), findsNothing);
      // The realised result is still the answer to the question asked.
      expect(find.text(r'+$17,953.50'), findsOneWidget);
    });

    testWidgets('renders in the dark theme', (tester) async {
      await pumpCard(tester, example, brightness: Brightness.dark);
      expect(find.byType(TaxLotRowTile), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}
