import 'package:finance_app/components/taxlots_table/taxlot_check_box.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_row_tile.dart';
import 'package:finance_app/components/taxlots_table/taxlot_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'taxlots_table_harness.dart';

/// The tick box, which is a **state and not a control** (AC-3).
///
/// It is bound to the payload's `fully_sold` — the lots this sale consumes
/// whole — and the view declares no action and no selection option, so the
/// kit's two artboards are two payloads rather than two interactions (spec
/// `frontend/0027` OD-3).
void main() {
  group(TaxLotCheckBox, () {
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

    testWidgets('is the kit 16 px box', (tester) async {
      await pumpRow(tester);
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

    testWidgets('ticks and tints a lot the sale consumes whole', (
      tester,
    ) async {
      await pumpRow(tester, fullySold: true);
      expect(rowBox(tester).color, TaxLotTokens.light.selectedRow);
      final box =
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byType(TaxLotCheckBox),
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
          of: find.byType(TaxLotCheckBox),
          matching: find.byType(CustomPaint),
        ),
        paints..path(
          color: TaxLotTokens.light.checkGlyph,
          style: PaintingStyle.stroke,
        ),
      );
    });

    testWidgets('leaves a partly sold lot untinted and its box empty', (
      tester,
    ) async {
      await pumpRow(tester);
      expect(rowBox(tester).color, isNull);
      final box =
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byType(TaxLotCheckBox),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(box.color, isNull);
      expect(box.border!.top.color, TaxLotTokens.light.checkboxBorder);
      // No tick is painted at all — not a tick in the background colour.
      expect(
        find.descendant(
          of: find.byType(TaxLotCheckBox),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('announces which lots the sale consumes', (tester) async {
      await pumpRow(tester, fullySold: true);
      expect(
        find.bySemanticsLabel(RegExp(TaxLotCheckBox.tickedLabel)),
        findsOneWidget,
      );
    });

    testWidgets('says of a partly consumed lot only what the flag says', (
      tester,
    ) async {
      // The negation of `fully_sold`, not a claim about what *was* sold.
      await pumpRow(tester);
      expect(TaxLotCheckBox.partialLabel, 'not fully sold');
      expect(
        find.bySemanticsLabel(RegExp(TaxLotCheckBox.partialLabel)),
        findsOneWidget,
      );
    });
  });
}
