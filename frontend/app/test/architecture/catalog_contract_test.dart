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
      for (final viewId in registry.viewIds) {
        final component = registry.lookup(viewId)!;
        expect(
          snapshot.viewIdFor(component.a2uiComponent),
          equals(viewId),
          reason:
              '${component.runtimeType} claims A2UI component '
              '"${component.a2uiComponent}", which the catalog serves under a '
              'different view id',
        );
      }
    });

    test('the snapshot still names the component this ticket bound', () {
      // A literal, on purpose. Every other assertion here reads both halves
      // from the same source and so cannot notice both changing together;
      // this is the client's own declaration of what design named, the
      // counterpart of the backend's `test_component_names.py`.
      expect(
        snapshot.viewIdFor('AttributionWaterfall'),
        'attribution.waterfall.v1',
      );
      expect(snapshot.viewIdFor('AllocationSummary'), 'holdings.allocation.v1');
    });

    test('the design page and the frozen catalog disagree on this name', () {
      // **Deliberate, and the reason it is pinned here.** The catalog names
      // this component `AllocationSummary`; design's own page for it
      // (`.design-refs/Catalog_HoldingsSummary.dc.html`, Zone 2) calls it
      // `HoldingsSummary` and gives it raw-number props. The backend's
      // `test_component_names.py` holds design's six names as a literal, so
      // the two declarations are already meant to be compared — and they no
      // longer agree.
      //
      // The client binds the **frozen catalog**, which is what the backend
      // actually serves; a client that registered the design page's name
      // would show a placeholder with a green gate, which is exactly the
      // defect GGU-53 was written for. This test fails the day somebody
      // reconciles them, which is the point: the reconciliation should be a
      // decision, not a silent rename. `specs/frontend/0007` OD-1 carries it.
      expect(
        () => snapshot.entryFor('HoldingsSummary'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
