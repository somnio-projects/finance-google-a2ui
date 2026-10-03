import 'package:finance_app/components/taxlots_table/taxlot_row_tile.dart';
import 'package:finance_app/components/taxlots_table/taxlot_sold_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'taxlots_table_harness.dart';

/// The fully-sold mark offers nothing to press and announces a status, never
/// a checkbox (GGU-148 AC-1): a box that looks tickable and ignores taps is a
/// control that lies about what it does.
void main() {
  group('$TaxLotSoldMark is not a control', () {
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

    testWidgets('offers nothing to press (GGU-148 AC-1)', (tester) async {
      for (final fullySold in <bool>[true, false]) {
        await pumpRow(tester, fullySold: fullySold);
        final row = find.byType(TaxLotRowTile);
        for (final control in <Type>[
          Checkbox,
          InkWell,
          GestureDetector,
          MouseRegion,
          Focus,
        ]) {
          expect(
            find.descendant(
              of: find.byType(TaxLotSoldMark),
              matching: find.byType(control),
            ),
            findsNothing,
            reason: '$control under the mark (fullySold: $fullySold)',
          );
        }
        final node = tester.getSemantics(row);
        expect(node, isSemantics(hasCheckedState: false));
        expect(
          node.label,
          contains(fullySold ? 'fully sold' : 'not fully sold'),
        );
      }
    });
  });
}
