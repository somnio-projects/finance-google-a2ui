import 'package:finance_app/components/holdings_allocation/allocation_gain.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_header.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_legend_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'holdings_allocation_class_fixture.dart';
import 'holdings_allocation_harness.dart';

void main() {
  group(AllocationGain, () {
    test('is a value over its four strings', () {
      // Built from a runtime string so the two are distinct objects and
      // equality goes through `props`, not through const canonicalisation.
      final period = 'all-time'.trim();
      AllocationGain gain(String trend) => AllocationGain(
        amountDisplay: r'+$61,204',
        percentDisplay: '+14.5%',
        trend: trend,
        period: period,
      );
      expect(gain('up'), equals(gain('up')));
      expect(gain('up'), isNot(equals(gain('down'))));
    });
  });

  group(HoldingsAllocationHeader, () {
    testWidgets('prints the gain line, glyph first, when the payload has one', (
      tester,
    ) async {
      await tester.pumpApp(HoldingsAllocationHeader(data: byClass()));
      expect(
        find.text(r'▲ +$61,204 (+14.5%)  all-time', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Total value'), findsNothing);
    });

    testWidgets('falls back to the total label without a gain block', (
      tester,
    ) async {
      await tester.pumpApp(const HoldingsAllocationHeader(data: twoCategories));
      expect(find.text(twoCategories.totalLabel), findsOneWidget);
    });

    for (final (trend, glyph) in <(String, String)>[
      ('down', '▼'),
      ('flat', '—'),
    ]) {
      testWidgets('a $trend gain takes the $glyph glyph', (tester) async {
        await tester.pumpApp(
          HoldingsAllocationHeader(
            data: byClass(
              gain: AllocationGain(
                amountDisplay: r'-$10',
                percentDisplay: '-0.1%',
                trend: trend,
                period: 'all-time',
              ),
            ),
          ),
        );
        expect(find.textContaining(glyph, findRichText: true), findsOneWidget);
      });
    }
  });
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
