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
      expect(data.subject.quantityDisplay, '0.25');
      expect(data.subject.priceDisplay, r'$64,250.00');
      expect(data.subject.proceedsDisplay, r'$16,062.50');
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
        r'$9,000.00',
        r'$10,617.00',
        r'$10,617.00',
      ]);
      expect(data.metrics[1].valueDisplays, <String>[
        r'+$7,062.50',
        r'+$5,445.50',
        r'+$5,445.50',
      ]);
      expect(data.metrics[2].valueDisplays.first, r'$0.00');
      expect(data.metrics[3].valueDisplays.first, r'+$7,062.50');
    });

    // `spread` has a suite of its own: `scenario_comparison_spread_test.dart`.

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
