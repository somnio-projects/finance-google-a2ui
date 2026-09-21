import 'package:finance_app/components/component_host.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_card.dart';
import 'package:finance_app/components/scenario_comparison/scenario_comparison_component.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'scenario_comparison_harness.dart';

void main() {
  group(ScenarioComparisonComponent, () {
    const component = ScenarioComparisonComponent();
    late Map<String, dynamic> example;

    setUp(() {
      example = scenarioExample();
    });

    test('serves the view id and component name the catalog publishes', () {
      expect(component.viewId, example['view']);
      expect(component.a2uiComponent, scenarioComponentName);
    });

    test('binds the subject once, outside the columns', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.title, 'Same sale, different lot method');
      expect(data.subject.label, 'Bitcoin');
      expect(data.subject.symbol, 'BTC');
      expect(data.subject.quantityDisplay, '0.18');
      expect(data.subject.priceDisplay, r'$64,250.00');
      expect(data.subject.proceedsDisplay, r'$11,565.00');
    });

    test('keeps the columns in the order the backend sent them', () {
      // N-10: ordering is the caller's `methods` option, never client
      // behaviour — and spec `backend/0017` AC-6 forbids sorting by outcome.
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.columns.map((column) => column.method), <String>[
        'FIFO',
        'LIFO',
        'HIFO',
      ]);
      expect(data.columns.first.label, 'FIFO — oldest lots first');
    });

    test('transposes the columns into four metric rows', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.metrics.map((row) => row.label), <String>[
        'Cost basis',
        'Realized P/L',
        'Short-term',
        'Long-term',
      ]);
      // Every cell is the backend's own display string, in column order.
      expect(data.metrics[0].valueDisplays, <String>[
        r'$7,740.00',
        r'$10,260.00',
        r'$10,260.00',
      ]);
      expect(data.metrics[1].valueDisplays, <String>[
        r'+$3,825.00',
        r'+$1,305.00',
        r'+$1,305.00',
      ]);
      expect(data.metrics[2].valueDisplays.first, r'$0.00');
      expect(data.metrics[3].valueDisplays.first, r'+$3,825.00');
    });

    test('binds the spread the backend measured, and names the ends', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.spread.amountDisplay, r'$2,520.00');
      expect(data.spread.highest, 'FIFO');
      expect(data.spread.lowest, 'LIFO');
      expect(data.spread.differs, isTrue);
    });

    test('agrees with the payload flag it deliberately does not read', () {
      // `ScenarioSpread.differs` is derived from the presence of the two
      // ends because `ViewPayload` has no boolean accessor and adding one
      // would edit a shared file (`specs/frontend/0003` OD-2). That is only
      // sound while the contract keeps the two in step, so the published
      // example is checked against the flag it carries, both ways.
      final differs = component.read(ViewPayload.fromJson(example));
      expect(differs.spread.differs, (example['spread']! as Map)['differs']);
      final flat = withoutSpreadEnds(example);
      final same = component.read(ViewPayload.fromJson(flat));
      expect(same.spread.differs, (flat['spread']! as Map)['differs']);
      expect(same.spread.highest, isNull);
      expect(same.spread.lowest, isNull);
    });

    test('keeps every note the backend attached', () {
      // N-9: a compliance note is never dropped. One of these is the
      // sentence that says no method is recommended.
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.notes, hasLength(2));
      expect(data.notes.first.label, 'Before tax');
      expect(data.notes.last.label, 'Not advice');
      expect(data.notes.last.text, contains('No method is recommended'));
    });

    test('raises the missing field instead of reconstructing it', () {
      expect(
        () => component.read(ViewPayload.fromJson(without(example, 'spread'))),
        throwsA(
          isA<PayloadContractException>().having(
            (error) => error.failure.path,
            'path',
            'spread.amount.display',
          ),
        ),
      );
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
      expect(find.byType(ScenarioComparisonCard), findsOneWidget);
      expect(find.text('Same sale, different lot method'), findsOneWidget);
    });

    group('register', () {
      test('adds exactly this component to a registry', () {
        final registry = ComponentRegistry();
        register(registry);
        expect(
          registry.lookup('scenario.comparison.v1'),
          isA<ScenarioComparisonComponent>(),
        );
        expect(registry.viewIds, hasLength(1));
      });
    });
  });
}
