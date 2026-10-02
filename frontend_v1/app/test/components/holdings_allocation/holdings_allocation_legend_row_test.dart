import 'package:finance_app/components/holdings_allocation/holdings_allocation_legend_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'holdings_allocation_class_fixture.dart';
import 'holdings_allocation_harness.dart';

/// The legend row's own suite. It shared a file with the header's until
/// GGU-145, which is how a file about one widget came to hold three groups —
/// split here by subject rather than by line count.
void main() {
  group(AllocationLegendRow, () {
    testWidgets('stacks the value over the signed day change', (tester) async {
      final data = byClass();
      await tester.pumpApp(
        AllocationLegendRow(
          // DeFi, the first row whose day is down: the glyph under test comes
          // from the declared trend, so the row has to carry one.
          category: data.categories[3],
          index: 3,
          selected: false,
          onTap: null,
          color: const Color(0xFF0F9D8F),
        ),
      );
      expect(find.text(r'$43,400'), findsOneWidget);
      expect(find.text('▼ -4.4%'), findsOneWidget);
      expect(find.text('9.0%'), findsOneWidget);
    });

    testWidgets('a flat change takes the dash; no change draws no line', (
      tester,
    ) async {
      final data = byClass();
      await tester.pumpApp(
        Column(
          children: <Widget>[
            AllocationLegendRow(
              category: data.categories[2],
              index: 2,
              selected: true,
              onTap: null,
              color: const Color(0xFF9AA0AA),
            ),
            AllocationLegendRow(
              category: twoCategories.categories.first,
              index: 0,
              selected: false,
              onTap: null,
              color: const Color(0xFF9AA0AA),
            ),
          ],
        ),
      );
      expect(find.text('— 0.0%'), findsOneWidget);
      expect(find.textContaining('▲'), findsNothing);
    });
  });
}
