import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_row_cells.dart';
import 'package:finance_app/components/taxlots_table/taxlot_row_tile.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlot_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'taxlots_table_harness.dart';

/// The row's pixels, asserted from the widget tree rather than a raster
/// (AC-1, AC-3).
///
/// ADR-L D-15 measured that glyph edges carry nearly all cross-platform
/// raster noise, and a tax-lot row is mostly glyphs. Reading the decoration
/// names the defect — "the rail is the wrong colour" — where a golden says
/// only that something moved. The tick and the tint are the same kind of
/// claim about the same row and live in `taxlot_check_box_test.dart`, which
/// is where AC-3 is proved.
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
            width: 600,
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

    Container rowBox(WidgetTester tester) => tester.widget<Container>(
      find
          .descendant(
            of: find.byType(TaxLotRowTile),
            matching: find.byType(Container),
          )
          .first,
    );

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

    testWidgets('is 41 px tall and carries no hairline of its own', (
      tester,
    ) async {
      // The kit's row is a band on the card, not the bordered box the
      // earlier artboard drew.
      await pumpRow(tester, TaxLotTerm.long);
      expect(
        tester.getSize(find.byType(TaxLotRowTile)).height,
        TaxLotMetrics.rowHeight,
      );
      expect(rowBox(tester).decoration, isNull);
      expect(rowBox(tester).color, isNull);
    });

    testWidgets('rails a long-term lot teal', (tester) async {
      await pumpRow(tester, TaxLotTerm.long);
      expect(railColor(tester), TaxLotTokens.longRail);
      expect(
        tester
            .getSize(
              find
                  .descendant(
                    of: find.byType(TaxLotRowTile),
                    matching: find.byType(ColoredBox),
                  )
                  .first,
            )
            .width,
        TaxLotMetrics.railWidth,
      );
    });

    testWidgets('rails a short-term lot amber', (tester) async {
      await pumpRow(tester, TaxLotTerm.short);
      expect(railColor(tester), TaxLotTokens.shortRail);
    });

    testWidgets('keeps the rail colour in the dark theme', (tester) async {
      await pumpRow(tester, TaxLotTerm.long, brightness: Brightness.dark);
      expect(railColor(tester), TaxLotTokens.longRail);
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

    testWidgets('prints the holding period the backend worded', (tester) async {
      // The goldens here are cropped to the left chrome and are deliberately
      // text-free (`taxlot_golden_frame.dart`), so **nothing else in this
      // suite can see this string reach the screen**. The duration is a
      // server string — the client has no clock to derive one with (N-13) —
      // and it sits beside the pill, as the artboard draws it.
      await pumpRow(tester, TaxLotTerm.long);

      expect(find.text('5.5 yr'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TaxLotRowTile),
          matching: find.text('Long-term'),
        ),
        findsOneWidget,
      );
    });
  });
}
