import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_card.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_component.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_drill.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';

/// Spec frontend/0041 AC-1..AC-3 — the drill button is its own node.
void main() {
  group('Drill button semantics (GGU-165)', () {
    for (final width in <double>[380, 642]) {
      testWidgets('is its own button node with its own rect at ${width}px, and '
          'a semantics tap sends one drill', (tester) async {
        final handle = tester.ensureSemantics();
        final sent = <String>[];
        final data = const AttributionWaterfallComponent().read(
          ViewPayload.fromJson(
            CatalogSnapshot.load().exampleForView('attribution.waterfall.v1'),
          ),
        );
        await tester.pumpApp(
          SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: width,
                child: AttributionWaterfallCard(
                  data: data,
                  initialSelectedKey: 'BTC',
                  drill: WaterfallDrill(
                    label: 'Break this down',
                    drivers: const <String>{'BTC'},
                    send: sent.add,
                  ),
                ),
              ),
            ),
          ),
        );

        final finder = find.bySemanticsLabel('Break this down, BTC · Bitcoin');
        final button = tester.getSemantics(finder);
        expect(button.flagsCollection.isButton, isTrue);
        expect(button.getSemanticsData().hasAction(SemanticsAction.tap), true);

        // Bounds are the button's, not the card's.
        final card = tester.getSize(find.byType(AttributionWaterfallCard));
        expect(button.rect.width, lessThan(card.width));
        expect(button.rect.height, lessThan(card.height / 4));

        // No ancestor is a button: children of one are presentational on
        // the web, which is how the node vanished into the card.
        for (var up = button.parent; up != null; up = up.parent) {
          expect(up.flagsCollection.isButton, isFalse);
          expect(up.label, isNot(contains('Break this down')));
        }

        // The chart's own semantics is still there, apart from the button.
        expect(find.text(data.title), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('Break this down')),
          findsOneWidget,
        );
        expect(find.textContaining('Bitcoin'), findsWidgets);

        tester.semantics.tap(
          find.semantics.byLabel('Break this down, BTC · Bitcoin'),
        );
        await tester.pumpAndSettle();
        expect(sent, <String>['BTC']);
        handle.dispose();
      });
    }
  });
}
