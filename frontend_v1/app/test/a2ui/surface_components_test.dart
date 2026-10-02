import 'package:finance_app/a2ui/surface_notice.dart';
import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/components/component_host.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/a2ui_fixtures.dart';
import '../helpers/catalog_snapshot.dart';
import 'surface_harness.dart';

/// Spec `frontend_v1/0001` AC-4: **every** registered component renders
/// from a v1.0 surface whose data model holds the backend's own example
/// payload — `{view, options, payload}` with the payload verbatim, the shape
/// ADR-M D-3 gives every render intent — with no transformation.
///
/// The two components the canonical examples carry are also proven against
/// the example files themselves (`surface_host_test.dart`); the others have
/// no v1.0 example file, so their surface is built around the published
/// catalog example, which is the payload `GET /v1/portfolios/current/views`
/// serves and therefore exactly what `dataModel.root.payload` will hold.
void main() {
  final snapshot = CatalogSnapshot.load();
  final registry = buildComponentRegistry();
  final viewIds = registry.viewIds.toList();

  test('the registry renders ten views', () {
    // Anti-vacuity: a loop over nothing would pass every case below.
    expect(viewIds, hasLength(10));
  });

  for (final viewId in viewIds) {
    testWidgets('$viewId renders from its v1.0 surface', (tester) async {
      final component = registry.lookup(viewId)!.a2uiComponent;
      final parents = bundledCatalog().components[component]!.allowedParents;
      final event = parents == null || parents.contains('Surface')
          ? surfaceEvent(
              surfaceId: 's-$viewId',
              component: component,
              payload: snapshot.exampleForView(viewId),
            )
          // A component that may not be a surface's root (the payoff chart,
          // ADR-M D-4) is drawn where the catalog allows it: as the child of
          // its first allowed parent, the way the agent composes it.
          : nestedSurfaceEvent(
              parent: parents.first,
              parentPayload: snapshot.exampleFor(parents.first),
              child: component,
              childPayload: snapshot.exampleForView(viewId),
            );
      await pumpSurface(tester, surfaceOf(event));
      expect(find.byType(ComponentHost), findsAtLeastNWidgets(1));
      expect(find.byType(SurfaceNotice), findsNothing);
      expect(find.textContaining('No component for'), findsNothing);
      expect(find.textContaining('Contract violation'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
