import 'package:finance_app/components/taxlots_table/taxlot_chip.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_tokens.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_footer.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'taxlots_table_harness.dart' as harness;

void main() {
  group(TaxLotsTableFooter, () {
    Future<void> pumpFooter(
      WidgetTester tester, {
      Brightness brightness = Brightness.light,
      List<TaxLotTermSplit> splits = harness.splits,
    }) => tester.pumpApp(
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 533.37,
            child: TaxLotsTableFooter(
              label: 'Realised P/L',
              totalDisplay: r'+$9,505.00',
              splits: splits,
            ),
          ),
        ),
      ),
      brightness: brightness,
    );

    testWidgets('shows the caption, the total and both halves', (tester) async {
      await pumpFooter(tester);
      expect(find.text('Realised P/L'), findsOneWidget);
      expect(find.text(r'+$9,505.00'), findsOneWidget);
      expect(find.text(r'+$580.00 Short-term'), findsOneWidget);
      expect(find.text(r'+$8,925.00 Long-term'), findsOneWidget);
    });

    testWidgets('keeps the halves in the order the backend sent them', (
      tester,
    ) async {
      await pumpFooter(tester);
      final chips = tester
          .widgetList<TaxLotChip>(find.byType(TaxLotChip))
          .toList();
      expect(chips.map((chip) => chip.label).toList(), <String>[
        r'+$580.00 Short-term',
        r'+$8,925.00 Long-term',
      ]);
      expect(
        chips.first.background,
        TaxLotTokens.light.shortTerm.chipBackground,
      );
      expect(chips.last.background, TaxLotTokens.light.longTerm.chipBackground);
    });

    testWidgets('draws the bar the design measures', (tester) async {
      await pumpFooter(tester);
      final box =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(TaxLotsTableFooter),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(box.color, TaxLotTokens.light.footerSurface);
      expect(box.borderRadius, TaxLotMetrics.footerBorderRadius);
    });

    testWidgets('draws the bar in the dark theme too', (tester) async {
      await pumpFooter(tester, brightness: Brightness.dark);
      final box =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(TaxLotsTableFooter),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(box.color, TaxLotTokens.dark.footerSurface);
    });

    testWidgets('the total is not coloured by the sign in its string', (
      tester,
    ) async {
      // `realized` carries no `direction`, and the two ways to recover one
      // — parsing "+" off the display, or taking the sign through the
      // geometry seam — are N-1 and a use ADR-L D-14 reserves for a canvas.
      // Spec `frontend/0003` OD-4 asks the backend for the field.
      await pumpFooter(tester);
      final total = tester.widget<Text>(find.text(r'+$9,505.00'));
      expect(total.style!.color, TaxLotTokens.light.primaryText);
      expect(total.style!.color, isNot(TaxLotTokens.light.gain));
    });
  });
}
