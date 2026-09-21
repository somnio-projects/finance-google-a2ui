import 'package:finance_app/components/component_host.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_card.dart';
import 'package:finance_app/components/taxlots_table/taxlots_table_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';
import 'taxlots_table_harness.dart';

void main() {
  group(TaxLotsTableComponent, () {
    const component = TaxLotsTableComponent();
    late Map<String, dynamic> example;

    setUp(() {
      example = CatalogSnapshot.load().exampleFor('TaxLotTable');
    });

    test('serves the view id the generated catalog publishes', () {
      // The literal is this build's own declaration of what design named,
      // the counterpart of the backend's `test_component_names.py`.
      expect(component.viewId, example['view']);
      expect(component.viewId, 'taxlots.table.v1');
      expect(component.a2uiComponent, 'TaxLotTable');
    });

    test('binds every lot the backend sent, in arrival order', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.lots.map((lot) => lot.label).toList(), <String>[
        'lot-btc-01',
        'lot-btc-02',
      ]);
      expect(data.lots.map((lot) => lot.term).toList(), <TaxLotTerm>[
        TaxLotTerm.long,
        TaxLotTerm.short,
      ]);
    });

    test('binds every figure from a display string', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.title, 'Tax lots this sale consumes');
      expect(data.subtitle, 'Sell 0.5 BTC under FIFO');
      expect(data.realizedLabel, 'Realised P/L');
      expect(data.realizedDisplay, r'+$9,505.00');
      expect(data.lots.first.costBasisDisplay, r'$18,060.00');
      expect(data.lots.first.proceedsDisplay, r'$26,985.00');
      expect(data.lots.first.gainLossDisplay, r'+$8,925.00');
      expect(data.lots.first.acquiredOn, '2025-01-13');
    });

    test('takes the split straight from by_term, never adding it up', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.splits.map((split) => split.label).toList(), <String>[
        'Short-term',
        'Long-term',
      ]);
      expect(
        data.splits.map((split) => split.realizedDisplay).toList(),
        <String>[r'+$580.00', r'+$8,925.00'],
      );
    });

    test('takes the two money captions from the payload, not from Dart', () {
      // The view declares a `locale` option, so a Dart constant here would
      // silently ignore it — the same argument the term label wins.
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.costBasisLabel, 'Cost basis');
      expect(data.proceedsLabel, 'Proceeds');
      final localised = component.read(
        ViewPayload.fromJson(<String, dynamic>{
          ...example,
          'proceeds': <String, dynamic>{
            ...example['proceeds']! as Map<String, dynamic>,
            'label': 'Ingresos',
          },
        }),
      );
      expect(localised.proceedsLabel, 'Ingresos');
    });

    test('labels a term from the by_term half that shares it', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.lots.first.termLabel, 'Long-term');
      expect(data.lots.last.termLabel, 'Short-term');
    });

    test('takes the gain colour from the trend enum, not a sign', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.lots.map((lot) => lot.trend).toList(), <TaxLotTrend>[
        TaxLotTrend.up,
        TaxLotTrend.up,
      ]);
      final falling = component.read(
        ViewPayload.fromJson(withLotField(example, 'trend', 'down')),
      );
      expect(falling.lots.first.trend, TaxLotTrend.down);
    });

    test('never reads the raw units, which N-4 reserves for geometry', () {
      final data = component.read(ViewPayload.fromJson(example));
      final bound = <String>[
        for (final lot in data.lots) ...<String>[
          lot.acquiredOn,
          lot.costBasisDisplay,
          lot.proceedsDisplay,
          lot.gainLossDisplay,
          lot.termLabel,
          lot.label,
        ],
      ];
      expect(bound, isNot(contains('0.42')));
      expect(bound, isNot(contains('18060.00')));
      expect(bound, isNot(contains('8925.000000')));
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
      expect(find.byType(TaxLotsTableCard), findsOneWidget);
      expect(find.text('Tax lots this sale consumes'), findsOneWidget);
    });
  });
}
