import 'package:finance_app/components/component_host.dart';
import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_card.dart';
import 'package:finance_app/components/holdings_allocation/holdings_allocation_component.dart';
import 'package:finance_app/features/catalog/view/catalog_card.dart';
import 'package:finance_app/features/catalog/view/catalog_grid.dart';
import 'package:finance_app/features/catalog/view/catalog_thumbnail.dart';
import 'package:finance_app/router/app_routes.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/pump_app.dart';
import '../catalog_fixtures.dart';

void main() {
  final entry = snapshotEntry('HoldingsSummary');
  final registry = ComponentRegistry()
    ..register(const HoldingsAllocationComponent());

  group(CatalogCard, () {
    testWidgets('binds the component, the summary, the id and the link', (
      tester,
    ) async {
      await tester.pumpApp(
        SizedBox(width: 310, height: 320, child: CatalogCard(entry: entry)),
        componentRegistry: registry,
      );
      expect(find.text(entry.component), findsOneWidget);
      expect(find.text(entry.summary), findsOneWidget);
      expect(find.text(entry.id), findsOneWidget);
      expect(find.text(CatalogCard.link), findsOneWidget);
      // The thumbnail is the real component, not a picture of one.
      expect(find.byType(HoldingsAllocationCard), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CatalogThumbnail),
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
      );
    });

    testWidgets('opens the component detail page when tapped', (tester) async {
      final router = GoRouter(
        initialLocation: AppRoutes.catalog,
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.catalog,
            builder: (context, state) => Scaffold(
              body: SizedBox(width: 310, child: CatalogCard(entry: entry)),
            ),
          ),
          GoRoute(
            path: AppRoutes.catalogDetail,
            builder: (context, state) => Text(
              'detail ${state.pathParameters[AppRoutes.catalogViewParameter]}',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        RepositoryProvider<ComponentRegistry>.value(
          value: registry,
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.tap(find.text(CatalogCard.link));
      await tester.pumpAndSettle();
      expect(find.text('detail ${entry.id}'), findsOneWidget);
      expect(catalogDetailRoute(entry.id), '/catalog/${entry.id}');
    });
  });

  group(CatalogThumbnail, () {
    testWidgets('lays the component out at a phone width and scales it', (
      tester,
    ) async {
      await tester.pumpApp(
        Center(
          child: SizedBox(
            width: 300,
            child: CatalogThumbnail(payload: entry.example),
          ),
        ),
        componentRegistry: registry,
      );
      final box = tester.getSize(find.byType(CatalogThumbnail));
      expect(box.height, CatalogThumbnail.height);
      expect(
        tester.getSize(find.byType(ComponentHost)).width,
        CatalogThumbnail.layoutWidth,
      );
    });
  });

  group(CatalogGrid, () {
    test('picks the columns by width', () {
      expect(CatalogGrid.columnsFor(1024), 3);
      expect(CatalogGrid.columnsFor(700), 2);
      expect(CatalogGrid.columnsFor(390), 1);
    });

    testWidgets('lays four cards out as two rows of three slots at 1024', (
      tester,
    ) async {
      final entries = List<CatalogEntry>.filled(4, entry);
      await tester.pumpApp(
        SingleChildScrollView(child: CatalogGrid(entries: entries)),
        componentRegistry: registry,
        surfaceSize: const Size(1024, 1200),
      );
      expect(find.byType(CatalogCard), findsNWidgets(4));
      expect(find.byType(IntrinsicHeight), findsNWidgets(2));
      final first = tester.getTopLeft(find.byType(CatalogCard).first);
      final last = tester.getTopLeft(find.byType(CatalogCard).last);
      expect(last.dy, greaterThan(first.dy));
      expect(last.dx, first.dx);
    });
  });
}
