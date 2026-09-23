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
      example = CatalogSnapshot.load().exampleForView(
        'attribution.waterfall.v1',
      );
    });

    test('serves the view id the generated catalog publishes', () {
      expect(component.viewId, example['view']);
      expect(component.a2uiComponent, 'AttributionWaterfall');
    });

    test('walks start, every bucket, then end, in arrival order', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.title, example['title']);
      expect(data.steps, hasLength(14 + 2));
      expect(data.steps.map((step) => step.key).toList(), <String>[
        ':start',
        'NVDA',
        'AAPL',
        'MSFT',
        'VOO',
        'GLD',
        'PYPL',
        'AGG',
        'BND',
        'VNQ',
        'XOM',
        'JNJ',
        'TIP',
        'PG',
        'USD',
        ':end',
      ]);
    });

    test('takes each bar direction from the backend enum, not a sign', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(
        data.steps.map((step) => step.step.kind).toList(),
        <WaterfallStepKind>[
          WaterfallStepKind.start,
          ...List<WaterfallStepKind>.filled(4, WaterfallStepKind.gain),
          ...List<WaterfallStepKind>.filled(9, WaterfallStepKind.loss),
          // Cash moves by $0.00 and the backend calls that `up`; the client
          // takes the enum, not the sign, which is the point of this test.
          WaterfallStepKind.gain,
          WaterfallStepKind.total,
        ],
      );
    });

    test('binds every figure from a display string', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.valueDisplays.first, r'$421,711.15');
      expect(data.valueDisplays[1], r'$34,019.40');
      expect(data.valueDisplays[5], r'-$10,500.00');
      expect(data.valueDisplays.last, r'$482,915.20');
      expect(data.steps[1].cumulativeDisplay, r'$455,730.55');
    });

    test('takes the geometry from the raw levels beside them', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.steps.first.step.level, closeTo(421711.15, 1e-9));
      expect(data.steps[1].step.level, closeTo(455730.55, 1e-9));
      expect(data.steps.last.step.level, closeTo(482915.2, 1e-9));
    });

    test('keeps every annotation the backend attached', () {
      final data = component.read(ViewPayload.fromJson(example));
      expect(data.annotations, hasLength(3));
      expect(data.annotations.last.label, 'Net');
      expect(data.annotations.last.text, r'$61,204.05');
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
