import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_row_cells.dart';
import 'package:finance_app/components/taxlots_table/taxlot_row_tile.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlot_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'taxlots_table_harness.dart';

/// The row's pixels, asserted from the widget tree rather than a raster.
///
/// ADR-L D-15 measured that glyph edges carry nearly all cross-platform
/// raster noise, and a tax-lot row is mostly glyphs — a golden of one would
/// sit close to its own tolerance and prove less than these do. Reading the
/// decoration names the defect ("the rail is the wrong colour") where a
/// golden would say only that something moved. Spec `frontend/0003` §7
/// records the trade.
void main() {
  group(TaxLotRowTile, () {
    Future<void> pumpRow(
      WidgetTester tester,
      TaxLotTerm term, {
      TaxLotTrend trend = TaxLotTrend.up,
      Brightness brightness = Brightness.light,
    }) => tester.pumpApp(
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 533.37,
            child: TaxLotRowTile(
              lot: lot(
                term: term,
                trend: trend,
                termLabel: term == TaxLotTerm.long ? 'Long-term' : 'Short-term',
              ),
            ),
          ),
        ),
      ),
      brightness: brightness,
    );

    BoxDecoration rowBox(WidgetTester tester) =>
        tester
                .widget<Container>(
                  find
                      .descendant(
                        of: find.byType(TaxLotRowTile),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration;

    Color railColor(WidgetTester tester) => tester
        .widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(TaxLotRowTile),
                matching: find.byType(ColoredBox),
              )
              .first,
        )
        .color;

    testWidgets('is 48 px tall with a 10 px radius, as the design draws it', (
      tester,
    ) async {
      await pumpRow(tester, TaxLotTerm.long);
      expect(
        tester.getSize(find.byType(TaxLotRowTile)).height,
        TaxLotMetrics.rowHeight,
      );
      expect(rowBox(tester).borderRadius, TaxLotMetrics.rowBorderRadius);
      expect(rowBox(tester).color, TaxLotTokens.light.surface);
      expect(rowBox(tester).border!.top.color, TaxLotTokens.light.border);
    });

    testWidgets('rails a long-term lot teal', (tester) async {
      await pumpRow(tester, TaxLotTerm.long);
      expect(railColor(tester), TaxLotTokens.light.longTerm.accent);
    });

    testWidgets('rails a short-term lot amber', (tester) async {
      await pumpRow(tester, TaxLotTerm.short);
      expect(railColor(tester), TaxLotTokens.light.shortTerm.accent);
    });

    testWidgets('rails a long-term lot teal in the dark theme too', (
      tester,
    ) async {
      await pumpRow(tester, TaxLotTerm.long, brightness: Brightness.dark);
      expect(railColor(tester), TaxLotTokens.dark.longTerm.accent);
      expect(rowBox(tester).color, TaxLotTokens.dark.surface);
    });

    testWidgets('colours a rising lot with the gain token', (tester) async {
      await pumpRow(tester, TaxLotTerm.long);
      final cell = tester.widget<TaxLotCell>(
        find.widgetWithText(TaxLotCell, r'+$8,925.00'),
      );
      expect(cell.style.color, TaxLotTokens.light.gain);
    });

    testWidgets('colours a falling lot with the loss token', (tester) async {
      await pumpRow(tester, TaxLotTerm.long, trend: TaxLotTrend.down);
      final cell = tester.widget<TaxLotCell>(
        find.widgetWithText(TaxLotCell, r'+$8,925.00'),
      );
      // The display string is unchanged — only the colour follows `trend`,
      // which is the whole point of not reading the sign off the string.
      expect(cell.style.color, TaxLotTokens.light.loss);
    });

    testWidgets('draws an empty tick box on every row', (tester) async {
      await pumpRow(tester, TaxLotTerm.long);
      expect(find.byType(TaxLotCheckBox), findsOneWidget);
      // The box is 16 px inside the design's fixed 26 px column, so the
      // size is read off the box and not off the cell that holds it.
      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(TaxLotCheckBox),
            matching: find.byType(Container),
          ),
        ),
        const Size.square(TaxLotMetrics.checkBoxSize),
      );
    });
  });
}
