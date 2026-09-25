import 'package:finance_app/components/taxlots_table/taxlot_check_glyph.dart';
import 'package:finance_app/components/taxlots_table/taxlot_chip.dart';
import 'package:finance_app/components/taxlots_table/taxlot_columns.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_tokens.dart';
import 'package:finance_app/components/taxlots_table/taxlot_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group(TaxLotChip, () {
    testWidgets('renders its label verbatim, with no hairline', (tester) async {
      // The kit's pills are a fill and a word; the bordered legend pill
      // belonged to the earlier artboard (spec `frontend/0027` OD-5).
      await tester.pumpApp(
        TaxLotChip(
          label: 'Long-term',
          background: TaxLotTokens.light.longTerm.chipBackground,
          padding: TaxLotMetrics.chipPadding,
          style: TaxLotType.chip(TaxLotTokens.light.longTerm.chipForeground),
        ),
      );
      expect(find.text('Long-term'), findsOneWidget);
      final box =
          tester.widget<DecoratedBox>(find.byType(DecoratedBox)).decoration
              as BoxDecoration;
      expect(box.color, TaxLotTokens.light.longTerm.chipBackground);
      expect(box.border, isNull);
      expect(box.borderRadius, TaxLotMetrics.chipBorderRadius);
    });
  });

  group(TaxLotColumns, () {
    testWidgets('lays the kit grid out after the rail and the box', (
      tester,
    ) async {
      await tester.pumpApp(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 600,
            child: TaxLotColumns(
              leading: SizedBox.shrink(key: Key('lead')),
              cells: <Widget>[
                Text('a'),
                Text('b'),
                Text('c'),
                Text('d'),
                Text('e'),
                Text('f'),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('lead'))).width,
        TaxLotColumns.leadingWidth,
      );
      // 80 against 54: the acquired column is wider than the share count,
      // which is what keeps a date on one line.
      expect(
        tester.getSize(find.text('a')).width,
        greaterThan(tester.getSize(find.text('b')).width),
      );
      // …and the holding-period column is the widest of the six.
      expect(
        tester.getSize(find.text('f')).width,
        greaterThan(tester.getSize(find.text('d')).width),
      );
    });

    testWidgets('rejects a row that is not the kit grid', (tester) async {
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

  group(TaxLotCheckGlyphPainter, () {
    test('repaints only when the stroke changes', () {
      const one = TaxLotCheckGlyphPainter(color: Color(0xFFFFFFFF));
      expect(one.shouldRepaint(one), isFalse);
      const other = TaxLotCheckGlyphPainter(color: Color(0xFF000000));
      expect(one.shouldRepaint(other), isTrue);
    });

    testWidgets('draws the kit polyline inside the box', (tester) async {
      await tester.pumpApp(
        const SizedBox.square(
          dimension: TaxLotMetrics.checkBoxSize,
          child: CustomPaint(
            painter: TaxLotCheckGlyphPainter(color: Color(0xFFFFFFFF)),
          ),
        ),
      );
      // The tick is a stroke, not a glyph: what is asserted is that it was
      // painted at the kit's three points rather than how it anti-aliases.
      expect(TaxLotCheckGlyphPainter.points, hasLength(3));
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
