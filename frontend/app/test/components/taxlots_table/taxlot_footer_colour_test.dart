import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlot_tokens.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'taxlots_table_harness.dart' as harness;

void main() {
  group('$TaxLotsTableFooter colours its total from the payload', () {
    // The colour is the payload's `realized.direction` resolved through the
    // palette — never the `+` in the string beside it, which is what N-1
    // forbids and what this group replaced an assertion of the *absence* of
    // the field with (`frontend/0027` OQ-4, `backend/0049` OD-4).
    Color totalColour(WidgetTester tester) => tester
        .widget<Text>(
          find.descendant(
            of: find.byType(TaxLotsTableFooter),
            matching: find.text(harness.footerTotalDisplay),
          ),
        )
        .style!
        .color!;

    testWidgets('takes the gain colour when the payload points up', (
      tester,
    ) async {
      await harness.pumpFooter(tester);

      expect(totalColour(tester), TaxLotTokens.light.gain);
    });

    testWidgets('takes the loss colour when the payload points down', (
      tester,
    ) async {
      await harness.pumpFooter(tester, trend: TaxLotTrend.down);

      expect(totalColour(tester), TaxLotTokens.light.loss);
    });

    testWidgets('stays neutral on a result that rounds to zero', (
      tester,
    ) async {
      // `flat` is the state the kit never drew and the contract permits:
      // a sale that realises less than half a cent. It takes the primary
      // text colour, not a third hue (`backend/0049` OD-7).
      await harness.pumpFooter(tester, trend: TaxLotTrend.flat);

      expect(totalColour(tester), TaxLotTokens.light.primaryText);
      expect(totalColour(tester), isNot(TaxLotTokens.light.gain));
    });
  });
}
