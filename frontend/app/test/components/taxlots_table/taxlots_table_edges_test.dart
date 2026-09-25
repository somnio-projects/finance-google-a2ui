import 'package:finance_app/components/taxlots_table/taxlot_mobile_tile.dart';
import 'package:finance_app/components/taxlots_table/taxlot_row_tile.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_card.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_data.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'taxlots_table_harness.dart';

/// The shapes of data the published example cannot show (AC-7).
///
/// Each is pumped at **both** widths, because the two forms lay out
/// differently and an overflow in one is invisible from the other. An
/// overflow is a red test here: `pumpApp`'s surface is deliberately small
/// enough for a tall card to trip it.
void main() {
  group('$TaxLotsTableCard edge cases', () {
    Future<void> pumpBoth(
      WidgetTester tester,
      TaxLotsTableData data,
      Future<void> Function(WidgetTester tester, double width) check,
    ) async {
      for (final width in <double>[360, 600]) {
        await tester.pumpApp(
          Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: width,
                  child: TaxLotsTableCard(data: data),
                ),
              ),
            ),
          ),
          surfaceSize: const Size(900, 2400),
        );
        expect(tester.takeException(), isNull, reason: 'at $width');
        await check(tester, width);
      }
    }

    testWidgets('one lot', (tester) async {
      await pumpBoth(tester, cardData(lots: <TaxLot>[lot()]), (
        tester,
        width,
      ) async {
        expect(
          width < 420
              ? find.byType(TaxLotMobileTile)
              : find.byType(TaxLotRowTile),
          findsOneWidget,
        );
      });
    });

    testWidgets('eight lots', (tester) async {
      final lots = <TaxLot>[
        for (var index = 0; index < 8; index++)
          lot(
            term: index.isEven ? TaxLotTerm.long : TaxLotTerm.short,
            termLabel: index.isEven ? 'Long-term' : 'Short-term',
            fullySold: index < 3,
          ),
      ];
      await pumpBoth(tester, cardData(lots: lots), (tester, width) async {
        expect(
          width < 420
              ? find.byType(TaxLotMobileTile)
              : find.byType(TaxLotRowTile),
          findsNWidgets(8),
        );
      });
    });

    testWidgets('every lot short-term', (tester) async {
      final lots = <TaxLot>[
        for (var index = 0; index < 3; index++)
          lot(term: TaxLotTerm.short, termLabel: 'Short-term'),
      ];
      await pumpBoth(tester, cardData(lots: lots), (tester, width) async {
        // The legend still keys both halves — it is `by_term`'s, not a
        // summary of the rows this client happened to receive (N-2).
        expect(find.text('Long-term'), findsOneWidget);
        expect(find.text('Short-term'), findsNWidgets(4));
      });
    });

    testWidgets('every lot long-term', (tester) async {
      final lots = <TaxLot>[for (var index = 0; index < 3; index++) lot()];
      await pumpBoth(tester, cardData(lots: lots), (tester, width) async {
        expect(find.text('Long-term'), findsNWidgets(4));
      });
    });

    testWidgets('a gain and a loss in the same table', (tester) async {
      final lots = <TaxLot>[
        lot(),
        lot(trend: TaxLotTrend.down, gainLossDisplay: r'-$1,240.00'),
      ];
      await pumpBoth(tester, cardData(lots: lots), (tester, width) async {
        expect(find.text(r'-$1,240.00'), findsOneWidget);
        expect(find.text(r'+$8,925.00'), findsWidgets);
      });
    });

    testWidgets('a title longer than the header was drawn for', (tester) async {
      // The contract bounds `title` at 120 characters, so this is the widest
      // string the backend may legally send.
      final data = cardData(lots: <TaxLot>[lot()], title: 'T' * 120);
      await pumpBoth(tester, data, (tester, width) async {
        expect(find.textContaining('TTTT'), findsOneWidget);
      });
    });
  });
}
