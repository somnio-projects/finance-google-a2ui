import 'package:finance_app/components/taxlots_table/taxlot_chip.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_tokens.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_footer.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'taxlots_table_harness.dart' as harness;

void main() {
  group(TaxLotsTableFooter, () {
    Future<void> pumpFooter(
      WidgetTester tester, {
      Brightness brightness = Brightness.light,
      List<TaxLotTermSplit> splits = harness.splits,
      String label = 'Realised P/L',
    }) => harness.pumpFooter(
      tester,
      brightness: brightness,
      halves: splits,
      label: label,
    );

    Divider rule(WidgetTester tester) => tester.widget<Divider>(
      find.descendant(
        of: find.byType(TaxLotsTableFooter),
        matching: find.byType(Divider),
      ),
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

    testWidgets('is a rule and a line of text, not a filled bar', (
      tester,
    ) async {
      // The kit dropped the earlier artboard's bordered footer bar; what
      // separates the total from the last row is one hairline.
      await pumpFooter(tester);
      expect(rule(tester).color, TaxLotTokens.light.divider);
      expect(rule(tester).thickness, TaxLotMetrics.dividerThickness);
      // The only *fills* under the footer are the two split pills: the
      // third decoration here is the rule's own hairline, which paints a
      // border and no background. A bar would show up as a fourth.
      final fills = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(TaxLotsTableFooter),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration as BoxDecoration)
          .where((decoration) => decoration.color != null)
          .toList();
      expect(fills, hasLength(harness.splits.length));
    });

    testWidgets('draws the rule in the dark theme too', (tester) async {
      await pumpFooter(tester, brightness: Brightness.dark);
      expect(rule(tester).color, TaxLotTokens.dark.divider);
    });

    testWidgets('takes its caption from the payload, both of the kit two', (
      tester,
    ) async {
      // *Realized gain if sold* and *Realized on selected sale* are the same
      // field with different content — the backend chooses, not the card.
      await pumpFooter(tester, label: 'Realized on selected sale');
      expect(find.text('Realized on selected sale'), findsOneWidget);
    });
  });
}
