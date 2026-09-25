import 'package:finance_app/components/taxlots_table/taxlot_column_headers.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_mobile_tile.dart';
import 'package:finance_app/components/taxlots_table/taxlot_row_tile.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_card.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_component.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_data.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_header.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';
import 'taxlot_raw_figures.dart';

/// The two forms the kit draws, and the one model behind them (AC-4).
///
/// The breakpoint is a property of the *card*, not of the screen: it is laid
/// out by whatever column the Assistant, the catalog or Home puts it in, so
/// these pump a `SizedBox` rather than a surface size (OD-7).
void main() {
  group('$TaxLotsTableCard at two widths', () {
    const component = TaxLotsTableComponent();
    late TaxLotsTableData data;

    setUp(() {
      data = component.read(
        ViewPayload.fromJson(CatalogSnapshot.load().exampleFor('TaxLotTable')),
      );
    });

    Future<void> pumpAt(
      WidgetTester tester,
      double width, {
      Brightness brightness = Brightness.light,
    }) => tester.pumpApp(
      Scaffold(
        body: SingleChildScrollView(
          child: Center(
            child: SizedBox(
              width: width,
              child: TaxLotsTableCard(data: data),
            ),
          ),
        ),
      ),
      brightness: brightness,
      surfaceSize: const Size(900, 1200),
    );

    /// The card's own width for a given content width — the breakpoint is
    /// measured inside the card's padding, where the `LayoutBuilder` sits.
    double cardFor(double content) =>
        content + TaxLotMetrics.cardPadding.horizontal;

    testWidgets('draws the table above the breakpoint', (tester) async {
      await pumpAt(tester, cardFor(TaxLotMetrics.stackBelow + 1));
      expect(find.byType(TaxLotRowTile), findsNWidgets(2));
      expect(find.byType(TaxLotMobileTile), findsNothing);
      expect(find.byType(TaxLotColumnHeaders), findsOneWidget);
      expect(
        tester
            .widget<TaxLotsTableHeader>(find.byType(TaxLotsTableHeader))
            .stacked,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('stacks the lots below it', (tester) async {
      await pumpAt(tester, cardFor(TaxLotMetrics.stackBelow - 1));
      expect(find.byType(TaxLotMobileTile), findsNWidgets(2));
      expect(find.byType(TaxLotRowTile), findsNothing);
      // No caption line: each block carries its own captions, which is what
      // the kit's phone artboard draws.
      expect(find.byType(TaxLotColumnHeaders), findsNothing);
      // …and the key drops under the title rather than squeezing it.
      expect(
        tester
            .widget<TaxLotsTableHeader>(find.byType(TaxLotsTableHeader))
            .stacked,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the same six values in both forms', (tester) async {
      // The breakpoint changes the arrangement, never the content — a card
      // that dropped a column on a phone would be deciding which of the
      // backend's figures matter.
      const values = <String>[
        '01/13/2025',
        '0.25',
        r'$9,000.00',
        r'$16,062.50',
      ];
      await pumpAt(tester, 360);
      for (final value in values) {
        expect(find.text(value), findsOneWidget, reason: 'phone: $value');
      }
      await pumpAt(tester, 600);
      for (final value in values) {
        expect(find.text(value), findsOneWidget, reason: 'desktop: $value');
      }
    });

    testWidgets('neither form puts a raw figure on screen', (tester) async {
      // N-4 over **every** path the catalog marks `binding: raw`, in both
      // trees: the phone form binds the same six values and inherits the
      // same obligation, and the two are different widgets.
      final raws = rawFigures(CatalogSnapshot.load().entryFor('TaxLotTable'));
      for (final width in <double>[cardFor(328), cardFor(600)]) {
        await pumpAt(tester, width);
        for (final raw in raws) {
          expect(find.text(raw), findsNothing, reason: '$raw at $width');
        }
      }
    });

    testWidgets('fits the kit phone width in the dark theme', (tester) async {
      await pumpAt(tester, 328, brightness: Brightness.dark);
      expect(find.byType(TaxLotMobileTile), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}
