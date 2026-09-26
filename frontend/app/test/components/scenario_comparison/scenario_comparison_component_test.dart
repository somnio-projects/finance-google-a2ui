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

    // `spread` has a suite of its own: `scenario_comparison_spread_test.dart`.

    test('keeps every note the backend attached', () {
      // N-9: a compliance note is never dropped. One states the rates the
      // card costed with and one says the recommendation is arithmetic under
      // them rather than advice — together they are what make the ranking
      // checkable (backend spec 0051 OD-4).
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.notes, hasLength(2));
      expect(data.notes.first.label, 'Illustrative rates');
      expect(data.notes.last.label, 'Not advice');
      expect(data.notes.first.text, contains('estimated at'));
      expect(
        data.notes.last.text,
        contains('arithmetic under the rates above, not advice'),
      );
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
