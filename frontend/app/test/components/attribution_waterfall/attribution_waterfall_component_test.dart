import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_card.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_component.dart';
import 'package:finance_app/components/component_host.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';
import 'attribution_waterfall_harness.dart';

void main() {
  group(AttributionWaterfallComponent, () {
    const component = AttributionWaterfallComponent();
    late Map<String, dynamic> example;

    setUp(() {
      example = CatalogSnapshot.load().exampleFor('AttributionWaterfall');
    });

    test('serves the view id the generated catalog publishes', () {
      expect(component.viewId, example['view']);
      expect(component.a2uiComponent, 'AttributionWaterfall');
    });

    test('walks start, every bucket, then end, in arrival order', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.title, example['title']);
      expect(data.steps, hasLength(5 + 2));
      expect(data.steps.map((step) => step.key).toList(), <String>[
        ':start',
        'BTC',
        'ETH',
        'SOL',
        'LINK',
        'DOGE',
        ':end',
      ]);
    });

    test('takes each bar direction from the backend enum, not a sign', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(
        data.steps.map((step) => step.step.kind).toList(),
        <WaterfallStepKind>[
          WaterfallStepKind.start,
          WaterfallStepKind.gain,
          WaterfallStepKind.loss,
          WaterfallStepKind.gain,
          WaterfallStepKind.loss,
          WaterfallStepKind.loss,
          WaterfallStepKind.total,
        ],
      );
    });

    test('binds every figure from a display string', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.valueDisplays.first, r'$56,925.00');
      expect(data.valueDisplays[1], r'$10,230.00');
      expect(data.valueDisplays[2], r'-$2,797.50');
      expect(data.valueDisplays.last, r'$65,038.60');
      expect(data.steps[1].cumulativeDisplay, r'$67,155.00');
    });

    test('takes the geometry from the raw levels beside them', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.steps.first.step.level, 56925);
      expect(data.steps[1].step.level, 67155);
      expect(data.steps.last.step.level, closeTo(65038.6, 1e-9));
    });

    test('keeps every annotation the backend attached', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.annotations, hasLength(3));
      expect(data.annotations.last.label, 'Net');
      expect(data.annotations.last.text, r'$8,113.60');
    });

    testWidgets('renders through the host the app really uses', (tester) async {
      // The path from an envelope to pixels: registry lookup, then
      // `ViewComponent.build`. Asserting `read()` alone would leave the
      // wiring that puts it on screen untested — the defect class that
      // makes a component invisible with a green gate.
      final registry = ComponentRegistry();
      register(registry);
      await tester.pumpApp(
        ComponentHost(
          registry: registry,
          payload: ViewPayload.fromJson(example),
        ),
      );
      expect(find.byType(AttributionWaterfallCard), findsOneWidget);
      expect(find.text('Unrealised P/L attribution'), findsOneWidget);
    });

    test('raises the missing field instead of reconstructing it', () {
      final broken = Map<String, dynamic>.from(example)..remove('end');
      expect(
        () => component.read(ViewPayload.fromJson(broken)),
        throwsA(
          isA<PayloadContractException>().having(
            (error) => error.failure.path,
            'path',
            'end.amount.amount',
          ),
        ),
      );
    });

    test('raises a direction the contract does not declare', () {
      expect(
        () => component.read(ViewPayload.fromJson(withDirection(example, '?'))),
        throwsA(
          isA<PayloadContractException>().having(
            (error) => error.failure.path,
            'path',
            'buckets[0].direction',
          ),
        ),
      );
    });

    test('raises a raw level that is not a decimal', () {
      expect(
        () => component.read(ViewPayload.fromJson(withBadLevel(example))),
        throwsA(
          isA<PayloadContractException>().having(
            (error) => error.failure.path,
            'path',
            'start.amount.amount',
          ),
        ),
      );
    });
  });
}
