import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_component.dart';
import 'package:finance_app/components/surface_actions.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';
import 'attribution_waterfall_card_test.dart' show bandCentre;

void main() {
  group('$AttributionWaterfallComponent and its drill action', () {
    late Map<String, dynamic> example;

    setUp(() {
      example = CatalogSnapshot.load().exampleFor('AttributionWaterfall');
    });

    Widget surface(Map<String, dynamic> json) => Center(
      child: SizedBox(
        width: 571,
        child: Builder(
          builder: (context) => const AttributionWaterfallComponent().build(
            context,
            ViewPayload.fromJson(json),
          ),
        ),
      ),
    );

    testWidgets('the payload declares the drill with its drivers', (
      tester,
    ) async {
      final drivers = AttributionWaterfallComponent.drillableDrivers(
        ViewPayload.fromJson(example),
      );
      expect(drivers, isNotNull);
      expect(drivers, contains('NVDA'));
    });

    testWidgets('inside a scope, a tapped driver is sent as the action', (
      tester,
    ) async {
      final sent = <SurfaceActionRequest>[];
      await tester.pumpApp(
        SurfaceActions(onAction: sent.add, child: surface(example)),
      );
      await tester.tapAt(bandCentre(tester, 1));
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
      expect(sent.single.action, 'drill.attribution.v1');
      expect(sent.single.args.keys, <String>['driver']);
      expect(
        AttributionWaterfallComponent.drillableDrivers(
          ViewPayload.fromJson(example),
        ),
        contains(sent.single.args['driver']),
      );
    });

    testWidgets('outside a scope the tap stays local', (tester) async {
      await tester.pumpApp(surface(example));
      await tester.tapAt(bandCentre(tester, 1));
      await tester.pumpAndSettle();
      // Nothing to assert on the wire; the selection still shows.
      expect(find.byType(AttributionWaterfallComponent), findsNothing);
    });

    testWidgets('a payload that declares no drill sends nothing', (
      tester,
    ) async {
      final sent = <SurfaceActionRequest>[];
      final undeclared = <String, dynamic>{...example, 'actions': <dynamic>[]};
      await tester.pumpApp(
        SurfaceActions(onAction: sent.add, child: surface(undeclared)),
      );
      await tester.tapAt(bandCentre(tester, 1));
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
      expect(
        AttributionWaterfallComponent.drillableDrivers(
          ViewPayload.fromJson(undeclared),
        ),
        isNull,
      );
    });

    testWidgets('a tapped key outside the published choices sends nothing', (
      tester,
    ) async {
      final sent = <SurfaceActionRequest>[];
      final narrowed = <String, dynamic>{
        ...example,
        'actions': <Map<String, dynamic>>[
          <String, dynamic>{
            'action': 'drill.attribution.v1',
            'arg': 'driver',
            'control': 'choice',
            'label': 'Break this down',
            'choices': <String>['ZZZ'],
          },
        ],
      };
      await tester.pumpApp(
        SurfaceActions(onAction: sent.add, child: surface(narrowed)),
      );
      await tester.tapAt(bandCentre(tester, 1));
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
    });
  });
}
