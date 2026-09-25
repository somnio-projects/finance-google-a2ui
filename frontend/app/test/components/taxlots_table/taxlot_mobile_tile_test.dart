import 'package:finance_app/components/taxlots_table/taxlot_check_box.dart';
import 'package:finance_app/components/taxlots_table/taxlot_column_headers.dart';
import 'package:finance_app/components/taxlots_table/taxlot_mobile_cell.dart';
import 'package:finance_app/components/taxlots_table/taxlot_mobile_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_mobile_tile.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlot_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'taxlots_table_harness.dart';

/// The phone block the kit draws below the breakpoint (AC-4).
void main() {
  group(TaxLotMobileTile, () {
    Future<void> pumpTile(
      WidgetTester tester, {
      TaxLotTerm term = TaxLotTerm.long,
      TaxLotTrend trend = TaxLotTrend.up,
      bool fullySold = false,
      Brightness brightness = Brightness.light,
    }) => tester.pumpApp(
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 328,
            child: TaxLotMobileTile(
              lot: lot(term: term, trend: trend, fullySold: fullySold),
              costBasisLabel: 'Cost basis',
              proceedsLabel: 'Proceeds',
            ),
          ),
        ),
      ),
      brightness: brightness,
    );

    testWidgets('stacks the date over a four-cell grid', (tester) async {
      await pumpTile(tester);
      expect(
        tester.getSize(find.byType(TaxLotMobileTile)).height,
        TaxLotMobileMetrics.tileHeight,
      );
      expect(find.text('03/12/2021'), findsOneWidget);
      expect(find.byType(TaxLotMobileCell), findsNWidgets(4));
      for (final caption in <String>[
        TaxLotColumnHeaders.shares,
        'Cost basis',
        'Proceeds',
        TaxLotColumnHeaders.gainLoss,
      ]) {
        expect(find.text(caption), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the same six values a table row does', (tester) async {
      await pumpTile(tester);
      for (final value in <String>[
        '03/12/2021',
        '30',
        r'$18,060.00',
        r'$26,985.00',
        r'+$8,925.00',
        'Long-term',
      ]) {
        expect(find.text(value), findsOneWidget, reason: value);
      }
    });

    testWidgets('tints and ticks a lot the sale consumes whole', (
      tester,
    ) async {
      await pumpTile(tester, fullySold: true);
      final tile = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(TaxLotMobileTile),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(tile.color, TaxLotTokens.light.selectedRow);
      expect(
        find.bySemanticsLabel(RegExp(TaxLotCheckBox.tickedLabel)),
        findsOneWidget,
      );
    });

    testWidgets('rails a short-term lot amber in the dark theme', (
      tester,
    ) async {
      await pumpTile(
        tester,
        term: TaxLotTerm.short,
        brightness: Brightness.dark,
      );
      final rail = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(TaxLotMobileTile),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(rail.color, TaxLotTokens.shortRail);
    });
  });

  group(TaxLotMobileCell, () {
    testWidgets('colours only the cell the trend belongs to', (tester) async {
      await tester.pumpApp(
        const Row(
          children: <Widget>[
            Expanded(
              child: TaxLotMobileCell(
                caption: 'Cost basis',
                value: r'$18,060.00',
                palette: TaxLotTokens.light,
              ),
            ),
            Expanded(
              child: TaxLotMobileCell(
                caption: TaxLotColumnHeaders.gainLoss,
                value: r'-$1,240.00',
                palette: TaxLotTokens.light,
                trend: TaxLotTrend.down,
              ),
            ),
          ],
        ),
      );
      expect(
        tester.widget<Text>(find.text(r'$18,060.00')).style!.color,
        TaxLotTokens.light.primaryText,
      );
      expect(
        tester.widget<Text>(find.text(r'-$1,240.00')).style!.color,
        TaxLotTokens.light.loss,
      );
    });
  });
}
