import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_callout.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_card.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_component.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_drill.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_drill_button.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';
import 'attribution_waterfall_card_test.dart' show bandCentre, phoneWidth;

/// Spec frontend/0040 AC-2, AC-3, OD-2 — the button, in both layouts.
void main() {
  group(AttributionWaterfallDrillButton, () {
    late List<String> sent;
    late WaterfallDrill drill;

    setUp(() {
      sent = <String>[];
      drill = WaterfallDrill(
        label: 'Break this down',
        drivers: const <String>{'BTC'},
        send: sent.add,
      );
    });

    Widget card({required double width, String? selected}) =>
        SingleChildScrollView(
          child: Center(
            child: SizedBox(
              width: width,
              child: AttributionWaterfallCard(
                data: const AttributionWaterfallComponent().read(
                  ViewPayload.fromJson(
                    CatalogSnapshot.load().exampleForView(
                      'attribution.waterfall.v1',
                    ),
                  ),
                ),
                drill: drill,
                initialSelectedKey: selected,
              ),
            ),
          ),
        );

    testWidgets('a phone card sends the selected key once per press', (
      tester,
    ) async {
      await tester.pumpApp(card(width: phoneWidth, selected: 'BTC'));
      final button = find.byType(AttributionWaterfallDrillButton);
      expect(button, findsOneWidget);
      await tester.tap(find.text('Break this down'));
      await tester.tap(find.text('Break this down'));
      await tester.pumpAndSettle();
      expect(sent, <String>['BTC', 'BTC']);
    });

    testWidgets('a desktop card shows the button beside the callout', (
      tester,
    ) async {
      await tester.pumpApp(card(width: 642, selected: 'BTC'));
      expect(find.byType(AttributionWaterfallCallout), findsOneWidget);
      await tester.ensureVisible(find.text('Break this down'));
      await tester.tap(find.text('Break this down'));
      await tester.pumpAndSettle();
      expect(sent, <String>['BTC']);
    });

    testWidgets('nothing is offered before a selection', (tester) async {
      await tester.pumpApp(card(width: phoneWidth));
      expect(find.byType(AttributionWaterfallDrillButton), findsNothing);
    });

    testWidgets('a selected key the drill does not list offers nothing', (
      tester,
    ) async {
      await tester.pumpApp(card(width: phoneWidth));
      // Band 2 is the second holding, which this drill does not list.
      await tester.tapAt(bandCentre(tester, 2));
      await tester.pumpAndSettle();
      expect(find.byType(AttributionWaterfallDrillButton), findsNothing);
    });

    testWidgets('the button names the bucket to a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(card(width: phoneWidth, selected: 'BTC'));
      expect(
        find.bySemanticsLabel('Break this down, BTC · Bitcoin'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
