import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_component.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_drill_button.dart';
import 'package:finance_app/components/attribution_window/attribution_window_component.dart';
import 'package:finance_app/components/surface_actions.dart';
import 'package:finance_app/components/view_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';
import 'attribution_waterfall_card_test.dart' show bandCentre;

/// Spec frontend/0040 — the tap selects; the selected bucket's button drills.
void main() {
  for (final (component, view) in <(ViewComponent, String)>[
    (const AttributionWaterfallComponent(), 'attribution.waterfall.v1'),
    (const AttributionWindowComponent(), 'attribution.window.v1'),
  ]) {
    group('$view and its drill action', () {
      late Map<String, dynamic> example;
      late List<SurfaceActionRequest> sent;

      setUp(() {
        example = CatalogSnapshot.load().exampleForView(view);
        sent = <SurfaceActionRequest>[];
      });

      Widget surface(Map<String, dynamic> json, {bool scoped = true}) {
        // Scrollable, so a button under a tall card can be brought into view.
        final card = SingleChildScrollView(
          child: Center(
            child: SizedBox(
              width: 571,
              child: Builder(
                builder: (context) =>
                    component.build(context, ViewPayload.fromJson(json)),
              ),
            ),
          ),
        );
        return scoped ? SurfaceActions(onAction: sent.add, child: card) : card;
      }

      Future<void> select(WidgetTester tester) async {
        await tester.tapAt(bandCentre(tester, 1));
        await tester.pumpAndSettle();
      }

      testWidgets('the tap only selects; the button sends the drill', (
        tester,
      ) async {
        await tester.pumpApp(surface(example));
        await select(tester);
        expect(sent, isEmpty, reason: 'AC-1: a tap sends nothing');

        final button = find.byType(AttributionWaterfallDrillButton);
        expect(button, findsOneWidget);
        expect(find.text('Break this down'), findsOneWidget);
        await tester.ensureVisible(find.text('Break this down'));
        await tester.tap(find.text('Break this down'));
        await tester.pumpAndSettle();

        expect(sent, hasLength(1));
        expect(sent.single.action, 'drill.attribution.v1');
        expect(sent.single.args.keys, <String>['driver']);
        final declared = ViewPayload.fromJson(example).rows('actions').single;
        expect(
          declared.strings('choices'),
          contains(sent.single.args['driver']),
        );
      });

      testWidgets('a second tap deselects and takes the button away', (
        tester,
      ) async {
        await tester.pumpApp(surface(example));
        await select(tester);
        await select(tester);
        expect(find.byType(AttributionWaterfallDrillButton), findsNothing);
        expect(sent, isEmpty);
      });

      testWidgets('outside a scope a selection offers no drill', (
        tester,
      ) async {
        await tester.pumpApp(surface(example, scoped: false));
        await select(tester);
        expect(find.byType(AttributionWaterfallDrillButton), findsNothing);
      });

      testWidgets('a payload that declares no drill offers none', (
        tester,
      ) async {
        await tester.pumpApp(
          surface(<String, dynamic>{...example, 'actions': <dynamic>[]}),
        );
        await select(tester);
        expect(find.byType(AttributionWaterfallDrillButton), findsNothing);
      });

      testWidgets('a key outside the published choices offers none', (
        tester,
      ) async {
        final narrowed = <String, dynamic>{
          ...example,
          'actions': <Map<String, dynamic>>[
            <String, dynamic>{
              'action': 'some.other.v1',
              'label': 'Other',
              'choices': <String>[],
            },
            <String, dynamic>{
              'action': 'drill.attribution.v1',
              'arg': 'driver',
              'control': 'choice',
              'label': 'Break this down',
              'choices': <String>['ZZZ'],
            },
          ],
        };
        await tester.pumpApp(surface(narrowed));
        await select(tester);
        expect(find.byType(AttributionWaterfallDrillButton), findsNothing);
      });
    });
  }
}
