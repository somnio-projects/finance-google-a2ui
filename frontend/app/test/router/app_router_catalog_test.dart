import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/features/catalog/view/catalog_card.dart';
import 'package:finance_app/features/catalog/view/catalog_detail_page.dart';
import 'package:finance_app/router/app_router.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../features/catalog/catalog_fixtures.dart';
import '../helpers/pump_app.dart';
import 'app_router_harness.dart';

/// The catalog's two routes, split from `app_router_test.dart` under the
/// 150-line budget (spec frontend/0016).
void main() {
  group('buildRouter catalog', () {
    late MockViewsRepository repository;

    setUp(() {
      repository = MockViewsRepository();
      when(
        () => repository.fetchPortfolioViews(
          portfolioId: any(named: 'portfolioId'),
          views: any(named: 'views'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Ok<RenderedViews>(renderedViews(extraViews: homeViews())),
      );
    });

    testWidgets('every registered component is reachable from the route', (
      tester,
    ) async {
      // The defect this closes: a component could be registered, 100 %-covered
      // and never reach a screen with a green gate. The index draws one card
      // per view the backend serves *and* the registry renders, so this
      // asserts against the real registry and the real generated catalog.
      final registry = buildComponentRegistry();
      when(() => repository.fetchCatalog())
          .thenAnswer((_) async => Ok<ViewCatalog>(snapshotCatalog()));
      await tester.binding.setSurfaceSize(const Size(1024, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpRouter(
        tester,
        buildRouter(initialLocation: AppRoutes.catalog),
        repository: repository,
        registry: registry,
      );
      await tester.pumpAndSettle();

      for (final viewId in registry.viewIds) {
        expect(
          find.byWidgetPredicate(
            (widget) => widget is CatalogCard && widget.entry.id == viewId,
          ),
          findsOneWidget,
          reason: '"$viewId" is registered and has no card on /catalog',
        );
      }
      expect(registry.viewIds, isNotEmpty);
    });

    testWidgets('serves a component detail page under the catalog', (
      tester,
    ) async {
      when(() => repository.fetchCatalog())
          .thenAnswer((_) async => Ok<ViewCatalog>(snapshotCatalog()));
      await pumpRouter(
        tester,
        buildRouter(initialLocation: catalogDetailRoute('taxlots.table.v1')),
        repository: repository,
        registry: buildComponentRegistry(),
      );
      await tester.pumpAndSettle();
      final page = tester.widget<CatalogDetailPage>(
        find.byType(CatalogDetailPage),
      );
      expect(page.viewId, 'taxlots.table.v1');
    });
  });
}
