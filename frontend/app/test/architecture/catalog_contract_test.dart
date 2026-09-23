import 'package:finance_app/components/component_manifest.g.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/catalog_snapshot.dart';

void main() {
  group('catalog contract', () {
    late CatalogSnapshot snapshot;
    late ComponentRegistry registry;

    setUp(() {
      snapshot = CatalogSnapshot.load();
      registry = ComponentRegistry();
      registerCatalogComponents(registry);
    });

    test('every registered component serves a view the backend publishes', () {
      // The gap GGU-53 was written for, closed on the client side: the
      // backend renamed four of six A2UI components in one commit, and a
      // client holding the old name registers happily, covers to 100 % and
      // shows a placeholder on screen. Reading the generated snapshot is
      // what makes that a red suite instead of a demo nobody rehearsed.
      expect(registry.viewIds, isNotEmpty);
      final published = <String>{
        for (final view in snapshot.views)
          (view['example'] as Map<String, dynamic>)['view'] as String,
      };
      for (final viewId in registry.viewIds) {
        expect(
          published,
          contains(viewId),
          reason:
              '"$viewId" is registered by this build and is not in '
              'docs/catalog/view-catalog.snapshot.json',
        );
      }
    });

    test('a component and its catalog entry agree on the A2UI name', () {
      // Resolved by **view id**, not by component name. Two views may share
      // a component — `AttributionWaterfall` draws the all-time walk and the
      // window walk (spec `backend/0039`) — and asking the snapshot by name
      // would silently answer with whichever comes first, which is the class
      // of quiet wrongness this suite exists to catch.
      for (final viewId in registry.viewIds) {
        final component = registry.lookup(viewId)!;
        expect(
          snapshot.entryForView(viewId)['component'] as String,
          equals(component.a2uiComponent),
          reason:
              '${component.runtimeType} claims A2UI component '
              '"${component.a2uiComponent}", which is not the name the '
              'catalog serves "$viewId" under',
        );
      }
    });

    test('asking the snapshot by a shared component name is refused', () {
      // The guard itself, measured: `AttributionWaterfall` now serves two
      // views, and a caller that asks by name gets an error instead of the
      // wrong example.
      expect(
        () => snapshot.entryFor('AttributionWaterfall'),
        throwsA(isA<StateError>()),
      );
    });

    test('the snapshot names the components the design pages name', () {
      // A literal, on purpose. Every other assertion here reads both halves
      // from the same source and so cannot notice both changing together;
      // this is the client's own declaration of what design named, the
      // counterpart of the backend's `test_component_names.py`.
      expect(
        snapshot.entryForView('attribution.waterfall.v1')['view'] as String,
        'attribution.waterfall.v1',
      );
      expect(snapshot.viewIdFor('HoldingsSummary'), 'holdings.allocation.v1');
      expect(snapshot.viewIdFor('RiskPayoffChart'), 'payoff.curve.v1');
      expect(
        snapshot.viewIdFor('ScenarioComparison'),
        'scenario.comparison.v1',
      );
      expect(snapshot.viewIdFor('OrderTicket'), 'order.ticket.v1');
      expect(snapshot.viewIdFor('TaxLotTable'), 'taxlots.table.v1');
    });

    test('the names design superseded are gone, not merely unused', () {
      // This replaces the pinned disagreement. The catalog used to name these
      // components `AllocationSummary` and `PayoffChart`, taken from the
      // gallery **cards** while their detail pages were not yet exported;
      // each page's own Zone 2 block calls them `HoldingsSummary` and
      // `RiskPayoffChart`, and spec 0024 §2 ruled that the detail page wins
      // because spec 0023 §3 had already said so.
      //
      // The predecessor of this test asserted the disagreement and said the
      // reconciliation "should be a decision, not a silent rename". It was
      // one. What is worth keeping is the other half: a superseded name must
      // not linger in the snapshot, because a client registering it would
      // draw a placeholder behind a green gate — the defect GGU-53 exists
      // for.
      for (final gone in <String>['AllocationSummary', 'PayoffChart']) {
        expect(
          () => snapshot.entryFor(gone),
          throwsA(isA<StateError>()),
          reason: r'$gone was superseded by the component detail page',
        );
      }
    });
  });
}
