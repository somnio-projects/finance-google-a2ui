import 'package:finance_app/components/taxlots_table/taxlot_chip.dart';
import 'package:finance_app/components/taxlots_table/taxlot_columns.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group(TaxLotChip, () {
    testWidgets('renders its label verbatim, unbordered by default', (
      tester,
    ) async {
      await tester.pumpApp(
        TaxLotChip(
          label: 'Long-term',
          background: const Color(0xFFDCEFEC),
          padding: TaxLotMetrics.rowChipPadding,
          style: TaxLotType.rowChip(const Color(0xFF0C6A60)),
        ),
      );
      expect(find.text('Long-term'), findsOneWidget);
      final box =
          tester.widget<DecoratedBox>(find.byType(DecoratedBox)).decoration
              as BoxDecoration;
      expect(box.color, const Color(0xFFDCEFEC));
      expect(box.border, isNull);
      expect(box.borderRadius, TaxLotMetrics.chipBorderRadius);
    });

    testWidgets('draws the legend hairline when one is given', (tester) async {
      await tester.pumpApp(
        TaxLotChip(
          label: 'Short-term',
          background: const Color(0xFFFDF0DC),
          border: const Color(0xFFF0D9A8),
          padding: TaxLotMetrics.legendChipPadding,
          style: TaxLotType.legendChip(const Color(0xFF8A5A10)),
        ),
      );
      final box =
          tester.widget<DecoratedBox>(find.byType(DecoratedBox)).decoration
              as BoxDecoration;
      expect(box.border, Border.all(color: const Color(0xFFF0D9A8)));
    });
  });

  group(TaxLotColumns, () {
    testWidgets('lays the design grid out after the fixed first column', (
      tester,
    ) async {
      await tester.pumpApp(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 533.37,
            child: TaxLotColumns(
              leading: SizedBox.shrink(key: Key('lead')),
              cells: <Widget>[
                Text('a'),
                Text('b'),
                Text('c'),
                Text('d'),
                Text('e'),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('lead'))).width,
        TaxLotMetrics.checkColumnWidth,
      );
      // 1.05fr against 0.95fr: the first flexible column is the wider one,
      // which is what keeps a date on one line.
      final a = tester.getSize(find.text('a')).width;
      final b = tester.getSize(find.text('b')).width;
      expect(a, greaterThan(b));
    });

    testWidgets('rejects a row that is not the design grid', (tester) async {
      // The assert lives in `build`, not the constructor, so it fires while
      // the element is built and the framework captures it.
      await tester.pumpApp(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: TaxLotColumns(
            leading: SizedBox.shrink(),
            cells: <Widget>[Text('only one')],
          ),
        ),
      );
      expect(tester.takeException(), isA<AssertionError>());
    });
  });
}
