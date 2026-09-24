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
      expect(data.symbol, 'NVDA');
      expect(data.name, 'NVIDIA Corp');
      expect(data.caption, 'Top contributor today');
      expect(data.contributionDisplay, r'+$4,370.40');
      expect(data.trend, DriverTrend.up);
    });

    test("binds the three tiles in the design's order, every figure a "
        'display string', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.tiles, <DriverTile>[
        const DriverTile(
          label: 'Price move',
          figure: '+4.20%',
          caption: r'+$48.56',
          trend: DriverTrend.up,
        ),
        const DriverTile(
          label: 'Shares',
          figure: '90',
          caption: r'@ $1,204.66',
        ),
        const DriverTile(
          label: 'Of day gain',
          figure: '134.88%',
          caption: r'of +$3,240.18',
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
      expect(find.text('NVIDIA Corp'), findsOneWidget);
      // N-4: no raw member reaches the screen.
      expect(find.textContaining('4370.4'), findsNothing);
      expect(find.textContaining('0.0420'), findsNothing);
      expect(find.textContaining('90.0000'), findsNothing);
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
