import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_row_tile.dart';
import 'package:finance_app/components/taxlots_table/taxlot_sold_mark.dart';
import 'package:finance_app/components/taxlots_table/taxlot_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'taxlots_table_harness.dart';

/// The fully-sold mark, which is a **state and not a control** (AC-3,
/// GGU-148 AC-1/AC-2).
///
/// It is bound to the payload's `fully_sold` — the lots this sale consumes
/// whole — and the view declares no action and no selection option, so the
/// kit's two artboards are two payloads rather than two interactions (spec
/// `frontend/0027` OD-3).
void main() {
  group(TaxLotSoldMark, () {
    Future<void> pumpRow(WidgetTester tester, {bool fullySold = false}) =>
        tester.pumpApp(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                child: TaxLotRowTile(lot: lot(fullySold: fullySold)),
              ),
            ),
          ),
        );

    Container rowBox(WidgetTester tester) => tester.widget<Container>(
      find
          .descendant(
            of: find.byType(TaxLotRowTile),
            matching: find.byType(Container),
          )
          .first,
    );

    testWidgets('is a round 16 px mark on a fully sold lot', (tester) async {
      await pumpRow(tester, fullySold: true);
      final mark = find.descendant(
        of: find.byType(TaxLotSoldMark),
        matching: find.byType(Container),
      );
      expect(
        tester.getSize(mark),
        const Size.square(TaxLotMetrics.soldMarkSize),
      );
      final box = tester.widget<Container>(mark).decoration! as BoxDecoration;
      expect(box.shape, BoxShape.circle);
    });

    testWidgets('ticks and tints a lot the sale consumes whole (AC-2)', (
      tester,
    ) async {
      await pumpRow(tester, fullySold: true);
      expect(rowBox(tester).color, TaxLotTokens.light.selectedRow);
      final box =
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byType(TaxLotSoldMark),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(box.color, TaxLotTokens.light.checkedBox);
      expect(box.border, isNull);
      // …and the tick itself reaches the canvas. Without this the glyph
      // could be deleted and every other assertion here would still pass.
      expect(
        find.descendant(
          of: find.byType(TaxLotSoldMark),
          matching: find.byType(CustomPaint),
        ),
        paints..path(
          color: TaxLotTokens.light.checkGlyph,
          style: PaintingStyle.stroke,
        ),
      );
    });

    testWidgets('draws nothing for a lot the sale does not consume whole', (
      tester,
    ) async {
      await pumpRow(tester);
      expect(rowBox(tester).color, isNull);
      // No hairline square and no tick: an empty box beside a ticked one is
      // what read as a checkbox (GGU-148).
      for (final drawn in <Type>[Container, DecoratedBox, CustomPaint]) {
        expect(
          find.descendant(
            of: find.byType(TaxLotSoldMark),
            matching: find.byType(drawn),
          ),
          findsNothing,
        );
      }
      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(TaxLotSoldMark),
            matching: find.byType(SizedBox),
          ),
        ),
        const Size.square(TaxLotMetrics.soldMarkSize),
      );
    });

    testWidgets('announces which lots the sale consumes', (tester) async {
      await pumpRow(tester, fullySold: true);
      expect(
        find.bySemanticsLabel(RegExp(TaxLotSoldMark.tickedLabel)),
        findsOneWidget,
      );
    });

    testWidgets('says of a partly consumed lot only what the flag says', (
      tester,
    ) async {
      // The negation of `fully_sold`, not a claim about what *was* sold.
      await pumpRow(tester);
      expect(TaxLotSoldMark.partialLabel, 'not fully sold');
      expect(
        find.bySemanticsLabel(RegExp(TaxLotSoldMark.partialLabel)),
        findsOneWidget,
      );
    });
  });
}
