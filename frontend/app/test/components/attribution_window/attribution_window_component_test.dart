import 'package:finance_app/components/attribution_window/attribution_window_component.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/catalog_snapshot.dart';

/// `attribution.window.v1` — a second registration of design's waterfall.
///
/// The example comes from the backend's generated snapshot, asked for **by
/// view id**: two views now share the component name `AttributionWaterfall`,
/// and asking by name would have handed this test the all-time walk's example
/// and passed anyway.
void main() {
  late Map<String, dynamic> example;

  setUp(() {
    example = CatalogSnapshot.load().exampleForView('attribution.window.v1');
  });

  group('AttributionWindowComponent', () {
    const component = AttributionWindowComponent();

    test('binds the view id the backend publishes', () {
      expect(component.viewId, 'attribution.window.v1');
    });

    test('registers under the name design already owns', () {
      // Not a new component: the same waterfall drawing a different
      // quantity, which is why the client needs no second painter.
      expect(component.a2uiComponent, 'AttributionWaterfall');
      expect(
        CatalogSnapshot.load().entryForView(
          'attribution.window.v1',
        )['component'],
        component.a2uiComponent,
      );
    });

    test(
      'reads the window example the all-time reader already understands',
      () {
        final data = component.read(ViewPayload.fromJson(example));

        expect(data.title, isNotEmpty);
        expect(data.steps, isNotEmpty);
      },
    );

    test('the title names the window, so the card never shows a bare walk', () {
      // The defect this view closes: a chart with no period on it beside a
      // sentence that has one.
      final data = component.read(ViewPayload.fromJson(example));

      expect(data.title, contains(example['period'] as String));
    });

    test('every figure it draws is a string the backend formatted', () {
      final data = component.read(ViewPayload.fromJson(example));

      for (final segment in data.steps) {
        expect(segment.valueDisplay, isNotEmpty);
        expect(segment.cumulativeDisplay, isNotEmpty);
      }
    });

    test('adds itself to a registry', () {
      final registry = ComponentRegistry();

      register(registry);

      expect(
        registry.lookup('attribution.window.v1'),
        isA<AttributionWindowComponent>(),
      );
    });
  });
}
