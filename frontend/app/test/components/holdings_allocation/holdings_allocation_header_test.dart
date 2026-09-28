import 'package:finance_app/components/holdings_allocation/allocation_gain.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_header.dart';
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
    testWidgets('prints the gain beside the title, as the payload wrote it', (
      tester,
    ) async {
      await tester.pumpApp(HoldingsAllocationHeader(data: byClass()));

      expect(
        find.text(r'+$61,204 (+14.5%) all-time', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('prepends no glyph — the sign is already in the string', (
      tester,
    ) async {
      // The design draws none, and one added here would be the client
      // restating the direction the backend already signed (N-1). The old
      // header did add one, so this would have passed either way before.
      await tester.pumpApp(HoldingsAllocationHeader(data: byClass()));

      for (final glyph in <String>['▲', '▼', '—']) {
        expect(find.textContaining(glyph, findRichText: true), findsNothing);
      }
    });

    testWidgets('takes its tone from the declared trend, never from the sign', (
      tester,
    ) async {
      // N-1's other half: the direction is an enum the backend sent, and
      // reading it off the `+`/`-` in the display string would be the client
      // interpreting a formatted figure. Every payload below carries the same
      // negative-looking figure, so only the trend can separate them.
      Future<(Color?, Color?)> tones(String trend) async {
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
        final rich = tester.widget<RichText>(
          find.textContaining('all-time', findRichText: true),
        );
        // `Text.rich` wraps the span in one carrying the inherited style, so
        // the two the header wrote are a level down.
        final spans =
            ((rich.text as TextSpan).children!.first as TextSpan).children!;
        return (spans.first.style?.color, spans.last.style?.color);
      }

      final up = await tones('up');
      final down = await tones('down');
      final flat = await tones('flat');

      expect(up.$1, isNot(down.$1));
      // A trend the design has no tone for falls back to the muted colour the
      // period is already drawn in, rather than to a third invented one.
      expect(flat.$1, flat.$2);
    });

    testWidgets('draws the title alone when the payload carries no gain', (
      tester,
    ) async {
      // `headline=false` is the case: a shell drew the header, so the card
      // has neither a gain nor a total of its own to show here.
      await tester.pumpApp(const HoldingsAllocationHeader(data: twoCategories));

      expect(find.text(twoCategories.title), findsOneWidget);
      expect(find.textContaining('all-time'), findsNothing);
    });

    testWidgets('speaks the total and the ring count it no longer draws', (
      tester,
    ) async {
      // The total moved into the ring and `center.*` stopped being drawn on
      // this variant; neither may stop reaching a person (N-9). The header is
      // one semantics node, so this is where both are said.
      final handle = tester.ensureSemantics();
      await tester.pumpApp(HoldingsAllocationHeader(data: byClass()));

      expect(
        tester.getSemantics(find.byType(HoldingsAllocationHeader)).label,
        allOf(
          contains(byClass().totalDisplay),
          contains(byClass().totalLabel),
          contains(byClass().centerCount),
        ),
      );
      handle.dispose();
    });
  });
}
