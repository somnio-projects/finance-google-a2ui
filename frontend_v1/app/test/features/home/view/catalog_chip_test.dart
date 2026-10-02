import 'package:finance_app/features/home/view/catalog_chip.dart';
import 'package:finance_app/router/app_routes.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group(CatalogChip, () {
    testWidgets('opens the catalog index', (tester) async {
      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) =>
                const Scaffold(body: Center(child: CatalogChip())),
          ),
          GoRoute(
            path: AppRoutes.catalog,
            builder: (context, state) => const Text('the catalog'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.tap(find.text(CatalogChip.label));
      await tester.pumpAndSettle();
      expect(find.text('the catalog'), findsOneWidget);
    });
  });
}
