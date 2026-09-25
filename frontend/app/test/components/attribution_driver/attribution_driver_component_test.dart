import 'package:finance_app/components/attribution_driver/attribution_driver_card.dart';
import 'package:finance_app/components/attribution_driver/attribution_driver_component.dart';
import 'package:finance_app/components/attribution_driver/attribution_driver_model.dart';
import 'package:finance_app/components/component_host.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';

void main() {
  group(AttributionDriverComponent, () {
    const component = AttributionDriverComponent();
    late Map<String, dynamic> example;

    setUp(() {
      example = CatalogSnapshot.load().exampleFor('DriverDetail');
    });

    test('serves the view id the generated catalog publishes', () {
      expect(component.viewId, example['view']);
      expect(component.a2uiComponent, 'DriverDetail');
    });

    test('binds the header from written strings', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.symbol, 'BTC');
      expect(data.name, 'Bitcoin');
      expect(data.caption, 'Top contributor today');
      expect(data.contributionDisplay, r'+$4,767.00');
      expect(data.trend, DriverTrend.up);
    });

    test("binds the three tiles in the design's order, every figure a "
        'display string', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.tiles, <DriverTile>[
        const DriverTile(
          label: 'Price move',
          figure: '+3.66%',
          caption: r'+$2,270.00',
          trend: DriverTrend.up,
        ),
        const DriverTile(
          label: 'Shares',
          figure: '2.1',
          caption: r'@ $64,250.00',
        ),
        const DriverTile(
          label: 'Of day gain',
          figure: '216.58%',
          caption: r'of +$2,201.05',
        ),
      ]);
    });

    testWidgets('renders through the host the app really uses', (tester) async {
      final registry = ComponentRegistry();
      register(registry);
      await tester.pumpApp(
        ComponentHost(
          registry: registry,
          payload: ViewPayload.fromJson(example),
        ),
      );
      expect(find.byType(AttributionDriverCard), findsOneWidget);
      expect(find.text('Bitcoin'), findsOneWidget);
      // N-4: no raw member reaches the screen.
      expect(find.textContaining('4767.0'), findsNothing);
      expect(find.textContaining('0.0366'), findsNothing);
      expect(find.textContaining('2.10000000'), findsNothing);
    });

    test('raises the missing field instead of reconstructing it', () {
      final broken = Map<String, dynamic>.from(example)..remove('shares');
      expect(
        () => component.read(ViewPayload.fromJson(broken)),
        throwsA(
          isA<PayloadContractException>().having(
            (error) => error.failure.path,
            'path',
            'shares.label',
          ),
        ),
      );
    });

    test('raises a trend the contract does not declare', () {
      final move = Map<String, dynamic>.from(
        example['price_move'] as Map<String, dynamic>,
      )..['trend'] = 'sideways';
      expect(
        () => component.read(
          ViewPayload.fromJson(<String, dynamic>{
            ...example,
            'price_move': move,
          }),
        ),
        throwsA(
          isA<PayloadContractException>().having(
            (error) => error.failure.path,
            'path',
            'price_move.trend',
          ),
        ),
      );
    });
  });
}
