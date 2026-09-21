import 'package:finance_app/components/taxlots_table/taxlot_dashed_box.dart';
import 'package:finance_app/components/taxlots_table/taxlot_metrics.dart';
import 'package:finance_app/components/taxlots_table/taxlot_tokens.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_empty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// The design's third zone-1 state, and the painter it needs.
///
/// `app/lib/charts/dashed_line.dart` dashes a straight horizontal run and
/// cannot follow a corner; widening it would mean editing a file the charts
/// own in order to add a component (ADR-L D-3), so the painter lives beside
/// the component and reuses that file's measured 4-on/3-off pattern.
void main() {
  group(TaxLotDashedBoxPainter, () {
    test('repaints only when something it draws changed', () {
      const painter = TaxLotDashedBoxPainter(
        color: Color(0xFFC4C6D0),
        radius: 10,
        strokeWidth: 1.5,
      );
      expect(painter.shouldRepaint(painter), isFalse);
      expect(
        painter.shouldRepaint(
          const TaxLotDashedBoxPainter(
            color: Color(0xFF3A3B44),
            radius: 10,
            strokeWidth: 1.5,
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          const TaxLotDashedBoxPainter(
            color: Color(0xFFC4C6D0),
            radius: 4,
            strokeWidth: 1.5,
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          const TaxLotDashedBoxPainter(
            color: Color(0xFFC4C6D0),
            radius: 10,
            strokeWidth: 3,
          ),
        ),
        isTrue,
      );
    });
  });

  group(TaxLotsTableEmpty, () {
    testWidgets('draws the dashed square and the sentence', (tester) async {
      await tester.pumpApp(const Scaffold(body: TaxLotsTableEmpty()));
      expect(find.text(TaxLotsTableEmpty.message), findsOneWidget);
      final paint = tester.widget<CustomPaint>(
        find
            .descendant(
              of: find.byType(TaxLotsTableEmpty),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      expect(
        (paint.painter! as TaxLotDashedBoxPainter).color,
        TaxLotTokens.light.placeholderBorder,
      );
      expect(paint.size.width, TaxLotMetrics.placeholderSize);
    });
  });
}
