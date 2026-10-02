import 'package:finance_app/components/taxlots_table/taxlot_figure.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_card.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'taxlots_table_harness.dart';

/// No figure on a row is ever cut (GGU-148 AC-3).
///
/// The repro's longest values, at the 360 px a phone gives the card: every
/// one is drawn whole — scaled if it must be, never ellipsised — so no row
/// prints a number the payload did not send.
void main() {
  const figures = <String>[r'+$16,336.50', r'$31,851.00', r'$48,187.50'];

  for (final width in <double>[360, 900]) {
    testWidgets('draws every figure whole at $width px', (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: width,
                child: TaxLotsTableCard(
                  data: cardData(
                    lots: <TaxLot>[
                      lot(gainLossDisplay: figures[0], fullySold: true),
                      lot(
                        term: TaxLotTerm.short,
                        termLabel: 'Short-term',
                        gainLossDisplay: figures[0],
                        unitsDisplay: '0.75000000',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      for (final text in tester.widgetList<Text>(
        find.descendant(
          of: find.byType(TaxLotFigure),
          matching: find.byType(Text),
        ),
      )) {
        expect(text.overflow, isNot(TextOverflow.ellipsis), reason: text.data);
        expect(text.maxLines, 1);
      }
      expect(find.text(figures[0]), findsNWidgets(2));
      expect(find.text('0.75000000'), findsOneWidget);
    });
  }

  testWidgets('scales a figure that does not fit instead of cutting it', (
    tester,
  ) async {
    await tester.pumpApp(
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 40,
            child: TaxLotFigure(figures[2], style: const TextStyle()),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<FittedBox>(find.byType(FittedBox)).fit,
      BoxFit.scaleDown,
    );
    expect(find.text(figures[2]), findsOneWidget);
  });

  testWidgets('aligns a figure with its column', (tester) async {
    for (final (align, expected) in <(TextAlign?, Alignment)>[
      (TextAlign.right, Alignment.centerRight),
      (TextAlign.end, Alignment.centerRight),
      (TextAlign.center, Alignment.center),
      (null, Alignment.centerLeft),
    ]) {
      await tester.pumpApp(
        TaxLotFigure(figures[1], style: const TextStyle(), align: align),
      );
      expect(
        tester.widget<FittedBox>(find.byType(FittedBox)).alignment,
        expected,
      );
    }
  });
}
