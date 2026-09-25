import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_card.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_component.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_header.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_notes.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';

/// The header (spec frontend/0028 AC-1): two of the backend's own strings in
/// the direction's mark, where a pill used to be.
void main() {
  const component = AttributionWaterfallComponent();
  late Map<String, dynamic> example;

  AttributionNet net(NetDirection direction) => AttributionNet(
    label: 'Net',
    amountDisplay: r'+$3,240',
    percentDisplay: '+0.68%',
    direction: direction,
  );

  setUp(() {
    example = CatalogSnapshot.load().exampleForView('attribution.waterfall.v1');
  });

  group('the headline', () {
    test('is read from `net`, signs included, and its direction', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.net.label, 'Net');
      expect(data.net.amountDisplay, r'+$61,204.05');
      expect(data.net.percentDisplay, '+14.51%');
      expect(data.net.direction, NetDirection.up);
    });

    test('raises a `net.direction` the contract does not declare', () {
      final broken = Map<String, dynamic>.from(
        example['net'] as Map<String, dynamic>,
      )..['direction'] = 'sideways';
      expect(
        () => component.read(
          ViewPayload.fromJson(<String, dynamic>{...example, 'net': broken}),
        ),
        throwsA(
          isA<PayloadContractException>().having(
            (error) => error.failure.path,
            'path',
            'net.direction',
          ),
        ),
      );
    });

    testWidgets('joins the amount and the percent with a middle dot', (
      tester,
    ) async {
      await tester.pumpApp(
        AttributionWaterfallHeader(
          title: "Today's drivers",
          net: net(NetDirection.up),
        ),
      );
      expect(find.text(r'+$3,240 · +0.68%'), findsOneWidget);
      // The pill, its glyph and its parentheses are gone (OD-1).
      expect(find.textContaining('▲'), findsNothing);
      expect(find.textContaining('('), findsNothing);
      expect(find.text('Net'), findsNothing);
    });

    testWidgets('marks the figure by the declared direction, never a sign', (
      tester,
    ) async {
      for (final (direction, colour) in <(NetDirection, Color)>[
        (NetDirection.up, ChartTokens.light.barGain),
        (NetDirection.down, ChartTokens.light.barLoss),
        (NetDirection.flat, ChartTokens.light.mutedLabel),
      ]) {
        await tester.pumpApp(
          AttributionWaterfallHeader(title: 'T', net: net(direction)),
        );
        expect(
          tester.widget<Text>(find.text(r'+$3,240 · +0.68%')).style?.color,
          colour,
        );
      }
    });

    testWidgets("keeps the payload's own label for a screen reader", (
      tester,
    ) async {
      // N-9: `net.label` is not printed, because the design does not print
      // it — but it is not dropped either.
      await tester.pumpApp(
        AttributionWaterfallHeader(title: 'T', net: net(NetDirection.up)),
      );
      expect(find.bySemanticsLabel(r'Net +$3,240 · +0.68%'), findsOneWidget);
    });

    testWidgets('sits on the card with the notes below it', (tester) async {
      await tester.pumpApp(
        Center(
          child: SizedBox(
            width: 571,
            child: AttributionWaterfallCard(
              data: component.read(ViewPayload.fromJson(example)),
            ),
          ),
        ),
      );
      expect(find.byType(AttributionWaterfallNotes), findsOneWidget);
      expect(find.text(r'Net $61,204.05'), findsOneWidget);
      final header = tester.getRect(find.byType(AttributionWaterfallHeader));
      final notes = tester.getRect(find.byType(AttributionWaterfallNotes));
      expect(header.bottom, lessThan(notes.top));
    });
  });
}
